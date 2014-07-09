class Http2::ResponseReader
  attr_reader :response

  def initialize(args)
    @mode = "headers"
    @transfer_encoding = nil
    @response = Http2::Response.new(:request_args => args, :debug => @debug)
    @rec_count = 0
    @args, @debug, @http2, @sock = args[:args], args[:debug], args[:http2], args[:sock]
    @nl = @http2.nl

    read_headers
    read_body
    finish
  end

  def read_headers
    loop do
      line = @sock.gets
      check_line_read(line)

      if line == "\n" || line == "\r\n" || line == @nl
        puts "Http2: Changing mode to body!" if @debug
        raise "No headers was given at all? Possibly corrupt state after last request?" if @response.headers.empty?
        break if @length == 0
        @mode = "body"
        @http2.on_content_call(@args, @nl)
        break
      end

      parse_header(line)
    end
  end

  def read_body
    loop do
      if @length && @length > 0
        line = @sock.read(@length)
        raise "Expected to get #{@length} of bytes but got #{line.bytesize}" if @length != line.bytesize
      else
        line = @sock.gets
      end

      check_line_read(line)
      stat = parse_body(line)
      break if stat == "break"
      next if stat == "next"
    end
  end

  def finish
    #Check if we should reconnect based on keep-alive-max.
    if @keepalive_max == 1 or @connection == "close"
      @sock.close unless @sock.closed?
    end

    # Validate that the response is as it should be.
    puts "Http2: Validating response." if @debug

    if !@response.args[:code]
      raise "No status-code was received from the server. Headers: '#{@response.headers}' Body: '#{resp.args[:body]}'."
    end

    @response.validate!
    check_and_decode
    check_and_follow_redirect
    handle_errors

    @http2.autostate_register(@response) if @http2.args[:autostate]
  end

private

  def check_and_follow_redirect
    if (@response.args[:code].to_s == "302" || @response.args[:code].to_s == "307") && @response.header?("location") && (!@http2.args.key?(:follow_redirects) || @http2.args[:follow_redirects])
      uri = URI.parse(@response.header("location"))
      url = uri.path
      url << "?#{uri.query}" if uri.query.to_s.length > 0

      args = {:host => uri.host}
      args[:ssl] = true if uri.scheme == "https"
      args[:port] = uri.port if uri.port

      puts "Http2: Redirecting from location-header to '#{url}'." if @debug

      if !args[:host] or args[:host] == @args[:host]
        return self.get(url)
      else
        http = Http2.new(args)
        return http.get(url)
      end
    end
  end

  def check_and_decode
    # Check if the content is gzip-encoded - if so: decode it!
    if @encoding == "gzip"
      puts "Http2: Decoding GZip." if @debug
      require "zlib"
      require "stringio"
      io = StringIO.new(@response.args[:body])
      gz = Zlib::GzipReader.new(io)
      untrusted_str = gz.read

      begin
        valid_string = ic.encode("UTF-8")
      rescue
        valid_string = untrusted_str.force_encoding("UTF-8").encode("UTF-8", :invalid => :replace, :replace => "").encode("UTF-8")
      end

      @response.args[:body] = valid_string
    end
  end

  def handle_errors
    if @http2.raise_errors
      if @response.args[:code].to_i == 500
        err = Http2::Errors::Internalserver.new("A internal server error occurred")
      elsif @response.args[:code].to_i == 403
        err = Http2::Errors::Noaccess.new("No access")
      elsif @response.args[:code].to_i == 400
        err = Http2::Errors::Badrequest.new("Bad request")
      elsif @response.args[:code].to_i == 404
        err = Http2::Errors::Notfound.new("Not found")
      end
    end

    if err
      err.response = @response
      raise err
    end
  end

  def check_line_read(line)
    if line
      @rec_count += line.length
    elsif !line && @rec_count <= 0
      @sock = nil
      raise Errno::ECONNABORTED, "Server closed the connection before being able to read anything (KeepAliveMax: '#{@keepalive_max}', Connection: '#{@connection}', PID: '#{Process.pid}')."
    end
  end

  def parse_cookie(cookie_line)
    ::Http2::Utils.parse_set_cookies(cookie_line).each do |cookie_data|
      @http2.cookies[cookie_data["name"]] = cookie_data
    end
  end

  def parse_keep_alive(keep_alive_line)
    if ka_max = keep_alive_line.match(/max=(\d+)/)
      @keepalive_max = ka_max[1].to_i
      print "Http2: Keepalive-max set to: '#{@keepalive_max}'.\n" if @debug
    end

    if ka_timeout = keep_alive_line.match(/timeout=(\d+)/)
      @keepalive_timeout = ka_timeout[1].to_i
      print "Http2: Keepalive-timeout set to: '#{@keepalive_timeout}'.\n" if @debug
    end
  end

  def parse_content_type(content_type_line)
    if match_charset = content_type_line.match(/\s*;\s*charset=(.+)/i)
      @charset = match_charset[1].downcase
      @response.args[:charset] = @charset
      content_type_line.gsub!(match_charset[0], "")
    end

    @ctype = content_type_line
    @response.args[:contenttype] = @content_type_line
  end

  #Parse a header-line and saves it on the object.
  #===Examples
  # http.parse_header("Content-Type: text/html\r\n")
  def parse_header(line)
    if match = line.match(/^(.+?):\s*(.+)#{@nl}$/)
      key = match[1].to_s.downcase

      parse_cookie(match[2]) if key == "set-cookie"
      parse_keep_alive(match[2]) if key == "keep-alive"
      parse_content_type(match[2]) if key == "content-type"

      if key == "connection"
        @connection = match[2].to_s.downcase
      elsif key == "content-encoding"
        @encoding = match[2].to_s.downcase
        puts "Http2: Setting encoding to #{@encoding}" if @debug
      elsif key == "content-length"
        @length = match[2].to_i
      elsif key == "transfer-encoding"
        @transfer_encoding = match[2].to_s.downcase.strip
      end

      puts "Http2: Parsed header: #{match[1]}: #{match[2]}" if @debug
      @response.headers[key] = [] unless @response.headers.key?(key)
      @response.headers[key] << match[2]

      if key != "transfer-encoding" && key != "content-length" && key != "connection" && key != "keep-alive"
        @http2.on_content_call(@args, line)
      end
    elsif match = line.match(/^HTTP\/([\d\.]+)\s+(\d+)\s+(.+)$/)
      @response.args[:code] = match[2]
      @response.args[:http_version] = match[1]

      @http2.on_content_call(@args, line)
    else
      raise "Could not understand header string: '#{line}'.\n\n#{@sock.read(409600)}"
    end
  end

  #Parses the body based on given headers and saves it to the result-object.
  # http.parse_body(str)
  def parse_body(line)
    if @response.args[:http_version] = "1.1"
      return "break" if @length == 0

      if @transfer_encoding == "chunked"
        parse_body_chunked(line)
      else
        puts "Http2: Adding #{line.to_s.bytesize} to the body." if @debug
        @response.args[:body] << line.to_s
        @http2.on_content_call(@args, line)
        return "break" if @response.header?("content-length") && @response.args[:body].length >= @response.header("content-length").to_i
      end
    else
      raise "Dont know how to read HTTP version: '#{@resp.args[:http_version]}'."
    end
  end

  def parse_body_chunked(line)
    len = line.strip.hex

    if len > 0
      read = @sock.read(len)
      return "break" if read == "" or (read == "\n" || read == "\r\n")
      @response.args[:body] << read
      @http2.on_content_call(@args, read)
    end

    nl = @sock.gets
    if len == 0
      if nl == "\n" || nl == "\r\n"
        return "break"
      else
        raise "Dont know what to do :'-("
      end
    end

    raise "Should have read newline but didnt: '#{nl}'." if nl != @nl
  end
end
