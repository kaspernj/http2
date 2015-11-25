class Http2::GetRequest < Http2::BaseRequest
  def execute
    @http2.mutex.synchronize do
      @http2.connection.write(headers_string)

      puts "Http2: Reading response." if @debug
      resp = @http2.read_response(self, @args)

      puts "Http2: Done with get request." if @debug
      return resp
    end
  end

  def headers_string
    unless @header_str
      @header_str = "#{method} /#{@args[:url]} HTTP/1.1#{@nl}"
      @header_str << @http2.header_str(@http2.default_headers(@args))
      @header_str << @nl
    end

    @header_str
  end

private

  def method
    if @args[:method]
      @args[:method].to_s.upcase
    else
      "GET"
    end
  end
end
