class Http2::PostRequest < Http2::BaseRequest
  def headers_string
    unless @headers_string
      @headers_string = "#{method} /#{@args[:url]} HTTP/1.1#{@nl}"
      @headers_string << @http2.header_str(headers)
      @headers_string << @nl
      @headers_string << @data
    end

    @headers_string
  end

  def execute
    @data = raw_data

    @http2.mutex.synchronize do
      puts "Http2: Doing post." if @debug

      @conn.write(headers_string)
      return @http2.read_response(self, @args)
    end
  end

private

  def method
    if @args[:method]
      @args[:method].to_s.upcase
    else
      "POST"
    end
  end

  def content_type
    if @args[:content_type]
      @args[:content_type]
    elsif @args[:json]
      "application/json"
    else
      "application/x-www-form-urlencoded"
    end
  end

  def raw_data
    if @args[:json]
      require "json" unless ::Kernel.const_defined?(:JSON)
      @args[:json].to_json
    elsif @args[:post].is_a?(String)
      @args[:post]
    else
      phash = @args[:post] ? @args[:post].clone : {}
      @http2.autostate_set_on_post_hash(phash) if @http2.args[:autostate]
      ::Http2::PostDataGenerator.new(phash).generate
    end
  end

  def headers
    headers_hash = {
      "Content-Length" => @data.bytesize,
      "Content-Type" => content_type
    }
    headers_hash.merge! @http2.default_headers(@args)
    headers_hash["Accept"] = "application/json" if @args[:json] && !headers_hash["Accept"]
    headers_hash
  end
end
