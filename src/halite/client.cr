require "./request"
require "./response"
require "./redirector"

require "http/client"
require "json"

module Halite
  # Clients make requests and receive responses
  #
  # Support all `Chainable` methods.
  #
  # ### Simple setup
  #
  # ```
  # client = Halite::Client.new(headers: {
  #   "private-token" => "bdf39d82661358f80b31b67e6f89fee4"
  # })
  #
  # client.auth(private_token: "bdf39d82661358f80b31b67e6f89fee4").
  #       .get("http://httpbin.org/get", params: {
  #         name: "icyleaf"
  #       })
  # ```
  #
  # ### Setup with block
  #
  # ```
  # client = Halite::Client.new |options|
  #   options.headers = {
  #     private_token: "bdf39d82661358f80b31b67e6f89fee4"
  #   }
  #   options.timeout.connect = 3.minutes
  #   options.logging = true
  # end
  # ```
  class Client
    include Chainable

    property options

    # Instance a new client
    #
    # ```
    # Halite::Client.new(headers: {"private-token" => "bdf39d82661358f80b31b67e6f89fee4"})
    # ```
    def self.new(*,
                 headers : (Hash(String, _) | NamedTuple)? = nil,
                 cookies : (Hash(String, _) | NamedTuple)? = nil,
                 params : (Hash(String, _) | NamedTuple)? = nil,
                 form : (Hash(String, _) | NamedTuple)? = nil,
                 json : (Hash(String, _) | NamedTuple)? = nil,
                 raw : String? = nil,
                 timeout = Timeout.new,
                 follow = Follow.new,
                 ssl : OpenSSL::SSL::Context::Client? = nil,
                 logging = false,
                 logger = nil)
      Client.new(Options.new(headers: headers, cookies: cookies, params: params,
        form: form, json: json, raw: raw, ssl: ssl,
        timeout: timeout, follow: follow,
        logging: logging, logger: logger))
    end

    # Instance a new client with block
    def self.new(&block)
      options = Options.new
      yield options
      Client.new(options)
    end

    # Instance a new client
    #
    # ```
    # options = Halite::Options.new(headers: {
    #   "private-token" => "bdf39d82661358f80b31b67e6f89fee4"
    # })
    #
    # client = Halite::Client.new(options)
    # ```
    def initialize(@options = Options.new)
      @history = [] of Response
    end

    # Make an HTTP request
    def request(verb : String, uri : String, options : Options? = nil) : Halite::Response
      opts = options ? @options.merge(options.not_nil!) : @options

      uri = make_request_uri(uri, opts)
      body_data = make_request_body(opts)
      headers = make_request_headers(opts, body_data.content_type)

      request = Request.new(verb, uri, headers, body_data.body)
      response = perform(request, opts)

      return response if opts.follow.hops.zero?

      Redirector.new(request, response, opts.follow.hops, opts.follow.strict).perform do |req|
        perform(req, opts)
      end
    end

    # Perform a single (no follow) HTTP request
    private def perform(request : Halite::Request, options : Halite::Options) : Halite::Response
      raise RequestError.new("SSL context given for HTTP URI = #{request.uri}") if request.scheme == "http" && options.ssl

      options.logger.request(request) if options.logging

      conn = HTTP::Client.new(request.domain, options.ssl)
      conn.connect_timeout = options.timeout.connect.not_nil! if options.timeout.connect
      conn.read_timeout = options.timeout.read.not_nil! if options.timeout.read
      conn_response = conn.exec(request.verb, request.full_path, request.headers, request.body)
      response = Response.new(request.uri, conn_response, @history)

      options.logger.response(response) if options.logging

      # Append history of response
      @history << response

      # Merge headers and cookies from response
      @options = merge_option_from_response(options, response)

      response
    rescue ex : IO::Timeout
      raise TimeoutError.new(ex.message)
    rescue ex : Socket::Error | Errno
      raise ConnectionError.new(ex.message)
    end

    # Merges query params if needed
    private def make_request_uri(uri : String, options : Halite::Options) : String
      uri = URI.parse uri
      if params = options.params
        query = HTTP::Params.escape(params)
        uri.query = [uri.query, query].compact.join("&") unless query.empty?
      end

      uri.path = "/" if uri.path.to_s.empty?
      uri.to_s
    end

    # Merges request headers
    private def make_request_headers(options : Halite::Options, content_type : String?) : HTTP::Headers
      headers = options.headers
      if (value = content_type) && !value.empty?
        headers.add("Content-Type", value)
      end

      # Cookie shards
      options.cookies.add_request_headers(headers)
    end

    # Create the request body object to send
    private def make_request_body(options : Halite::Options) : Halite::Request::Data
      if (form = options.form) && !form.empty?
        FormData.create(form)
      elsif (hash = options.json) && !hash.empty?
        body = JSON.build do |builder|
          hash.to_json(builder)
        end

        Halite::Request::Data.new(body, "application/json")
      elsif (raw = options.raw) && !raw.empty?
        Halite::Request::Data.new(raw, "text/plain")
      else
        Halite::Request::Data.new("")
      end
    end

    private def merge_option_from_response(options : Halite::Options, response : Halite::Response) : Halite::Options
      return options unless response.headers
      # Store cookies for sessions use
      options.with_cookies(HTTP::Cookies.from_headers(response.headers))
    end
  end
end
