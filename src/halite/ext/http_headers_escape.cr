module HTTP
  struct Headers
    # Returns the given key value pairs as HTTP Headers
    #
    # Every parameter added is directly written to an IO, where keys are properly escaped.
    #
    # ```
    # HTTP::Headers.escape({
    #   content_type: "application/json",
    # })
    # # => "HTTP::Headers{"Content-Type" => "application/json"}"
    #
    # HTTP::Headers.escape({
    #   "conTENT-type": "application/json",
    # })
    # # => "HTTP::Headers{"Content-Type" => "application/json"}"
    # ```
    def self.escape(data : Hash(String, _) | NamedTuple) : HTTP::Headers
      ::HTTP::Headers.new.tap do |builder|
        data = data.is_a?(NamedTuple) ? data.to_h : data
        data.each do |key, value|
          key = key.to_s.gsub("_", "-").split("-").map { |v| v.capitalize }.join("-")
          # skip invaild value of content length
          next if key == "Content-Length" && !(value =~ /^\d+$/)

          builder.add key, value.is_a?(Array(String)) ? value : value.to_s
        end
      end
    end

    # Same as `#escape`
    def self.escape(**data)
      escape(data)
    end

    # Overwrite original `Hash#to_h`
    def to_h
      @hash.each_with_object({} of String => String | Array(String)) do |(key, values), obj|
        obj[key.name] = values.size == 1 ? values[0].as(String) : values.as(Array(String))
      end
    end
  end
end
