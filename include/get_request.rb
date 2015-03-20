class Http2::GetRequest
  def initialize(http2, args)
    @http2, @args, @debug, @nl = http2, http2.parse_args(args), http2.debug?, http2.nl
  end

  def execute
    @http2.mutex.synchronize do
      @http2.debug "Writing headers: #{header_string}" if @debug
      @http2.connection.write(header_string)

      @http2.debug "Reading response." if @debug
      resp = @http2.read_response(@args)

      @http2.debug "Done with get request." if @debug
      return resp
    end
  end

private

  def method
    if @args[:method]
      @args[:method].to_s.upcase
    else
      "GET"
    end
  end

  def header_string
    header_str = "#{method} /#{@args[:url]} HTTP/1.1#{@nl}"
    header_str << @http2.header_str(@http2.default_headers(@args), @args)
    header_str << @nl
  end
end
