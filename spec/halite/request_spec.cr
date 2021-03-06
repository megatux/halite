require "../spec_helper"

private def request
  Halite::Request.new(
    "get",
    "http://example.com/foo/bar?q=halite#result",
    HTTP::Headers{"Accept" => "text/html"},
  )
end

describe Halite::Request do
  describe "#verb" do
    it "provides a #verb getter with upcase" do
      request.verb.should eq "GET"
    end
  end

  describe "#scheme" do
    it "provides a #scheme getter" do
      request.scheme.should eq "http"
    end
  end

  describe "#headers" do
    it "provides a given headers" do
      request.headers["Accept"].should eq "text/html"
    end

    it "could not set header with key and value" do
      request.headers["User-Agent"] = "Halite"
      request.headers["User-Agent"]?.should eq nil
    end
  end

  describe "#domain" do
    it "return `URI` with the scheme, user, password, port and host combined" do
      request.domain.to_s.should eq "http://example.com"
    end

    context "when subdomain and path are the same" do
      it "return `URI` with the scheme, user, password, port and host combined" do
        Halite::Request.new("get", "https://login.example.com/login").domain.to_s.should eq "https://login.example.com"
      end
    end
  end

  describe "#full_path" do
    it "provides a full_path" do
      request.full_path.should eq "/foo/bar?q=halite#result"
    end
  end

  describe "#body" do
    it "provides a body" do
      request.body.should eq ""
    end
  end

  describe "#redirect" do
    pending do
      "todo"
    end
  end

  describe "raises" do
    it "should throws an exception with not allowed request method" do
      expect_raises Halite::UnsupportedMethodError, "Unknown method: TRACE" do
        Halite::Request.new("trace", "http://httpbin.org/get")
      end
    end

    it "should throws an exception without scheme part of URI" do
      expect_raises Halite::UnsupportedSchemeError, "Missing scheme: example.com" do
        Halite::Request.new("get", "example.com")
      end
    end

    it "should throws an exception with not allowed scheme part of URI" do
      expect_raises Halite::UnsupportedSchemeError, "Unknown scheme: ws" do
        Halite::Request.new("get", "ws://example.com")
      end
    end
  end
end
