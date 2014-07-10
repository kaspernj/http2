class Http2::ResponseReader
  attr_reader :response

  def initialize(args)
    @mode = "headers"
    @transfer_encoding = nil
    @response = Http2::Response.new(:request_args => args, :debug => @debug)
    @rec_count = 0
    @args, @debug, @http2, @sock = args[:args], args[:http2].debug, args[:http2], args[:sock]
    @nl = @http2.nl
    @conn = @http2.connection

    read_headers
    read_body if @length == nil || @length > 0
    finish
  end

  def read_headers
    loop do
      line = @conn.gets
      check_line_read(line)

      if line == "\n" || line == "\r\n" || line == @nl
        puts "Http2: Changing mode to body!" if @debug
        raise "No headers was given at all? Possibly corrupt state after last request?" if @response.headers.empty?
        @mode = "body"
        @http2.on_content_call(@args, @nl)
        break
      end

      parse_header(line)
    end
  end

  def read_body
    loop do
      if @length
        line = @conn.read(@length)
        raise "Expected to get #{@length} of bytes but got #{line.bytesize}" if @length != line.bytesize
      else
        line = @conn.gets
      end

      check_line_read(line)
      stat = parse_body(line)
      break if stat == :break
      next if stat == :next
    end
  end

  def finish
    #Check if we should reconnect based on keep-alive-max.
    if @keepalive_max == 1 || @connection == "close"
      @conn.close unless @conn.closed?
    end

    # Validate that the response is as it should be.
    puts "Http2: Validating response." if @debug

    if !@response.code
      raise "No status-code was received from the server. Headers: '#{@response.headers}' Body: '#{resp.body}'."
    end

    @response.validate!
    check_and_decode
    @http2.autostate_register(@response) if @http2.args[:autostate]
    handle_errors

    if response = check_and_follow_redirect
      @response = response
    end
  end

private

  def check_and_follow_redirect
    if (@response.code == "302" || @response.code == "307") && @response.header?("location") && @http2.args[:follow_redirects]
      url, args = url_and_args_from_location

      if !args[:host] || args[:host] == @args[:host]
        return @http2.get(url)
      else
        ::Http2.new(args).get(url)
      end
    end
  end

  def url_and_args_from_location
    uri = URI.parse(@response.header("location"))
    url = uri.path
    url << "?#{uri.query}" if uri.query.to_s.length > 0

    args = {host: uri.host}
    args[:ssl] = true if uri.scheme == "https"
    args[:port] = uri.port if uri.port

    return [url, args]
  end

  def check_and_decode
    # Check if the content is gzip-encoded - if so: decode it!
    if @encoding == "gzip"
      puts "Http2: Decoding GZip." if @debug
      require "zlib"
      require "stringio"
      io = StringIO.new(@response.body)
      gz = Zlib::GzipReader.new(io)
      untrusted_str = gz.read

      begin
        valid_string = ic.encode("UTF-8")
      rescue
        valid_string = untrusted_str.force_encoding("UTF-8").encode("UTF-8", :invalid => :replace, :replace => "").encode("UTF-8")
      end

      @response.body = valid_string
    end
  end

  def handle_errors
    return unless  @http2.raise_errors

    if @response.code == "500"
      err = Http2::Errors::Internalserver.new("A internal server error occurred")
    elsif @response.code == "403"
      err = Http2::Errors::Noaccess.new("No access")
    elsif @response.code == "400"
      err = Http2::Errors::Badrequest.new("Bad request")
    elsif @response.code == "404"
      err = Http2::Errors::Notfound.new("Not found")
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
      raise Errno::ECONNABORTED, "Server closed the connection before being able to read anything (KeepAliveMax: '#{@http2.keepalive_max}', Connection: '#{@connection}', PID: '#{Process.pid}')."
    end
  end

  def parse_cookie(cookie_line)
    ::Http2::Utils.parse_set_cookies(cookie_line).each do |cookie_data|
      @http2.cookies[cookie_data["name"]] = cookie_data
    end
  end

  def parse_keep_alive(keep_alive_line)
    keep_alive_line.scan(/([a-z]+)=(\d+)/) do |match|
      if match[0] == "timeout"
        puts "Http2: Keepalive-max set to: '#{@keepalive_max}'." if @debug
        @http2.keepalive_timeout = match[1].to_i
      elsif match[0] == "max"
        puts "Http2: Keepalive-timeout set to: '#{@keepalive_timeout}'." if @debug
        @http2.keepalive_max = match[1].to_i
      end
    end
  end

  def parse_content_type(content_type_line)
    if match_charset = content_type_line.match(/\s*;\s*charset=(.+)/i)
      @charset = match_charset[1].downcase
      @response.charset = @charset
      content_type_line.gsub!(match_charset[0], "")
    end

    @response.content_type = @content_type_line
  end

  #Parse a header-line and saves it on the object.
  #===Examples
  # http.parse_header("Content-Type: text/html\r\n")
  def parse_header(line)
    if match = line.match(/^(.+?):\s*(.+)#{@nl}$/)
      key = match[1].downcase
      set_header_special_values(key, match[2])
      parse_normal_header(line, key, match[1], match[2])
    elsif match = line.match(/^HTTP\/([\d\.]+)\s+(\d+)\s+(.+)$/)
      @response.code = match[2]
      @response.http_version = match[1]
      @http2.on_content_call(@args, line)
    else
      raise "Could not understand header string: '#{line}'."
    end
  end

  def set_header_special_values(key, value)
    parse_cookie(value) if key == "set-cookie"
    parse_keep_alive(value) if key == "keep-alive"
    parse_content_type(value) if key == "content-type"

    if key == "connection"
      @connection = value.downcase
    elsif key == "content-encoding"
      @encoding = value.downcase
      puts "Http2: Setting encoding to #{@encoding}" if @debug
    elsif key == "content-length"
      @length = value.to_i
    elsif key == "transfer-encoding"
      @transfer_encoding = value.downcase.strip
    end
  end

  def parse_normal_header(line, key, orig_key, value)
    puts "Http2: Parsed header: #{orig_key}: #{value}" if @debug
    @response.headers[key] = [] unless @response.headers.key?(key)
    @response.headers[key] << value

    if key != "transfer-encoding" && key != "content-length" && key != "connection" && key != "keep-alive"
      @http2.on_content_call(@args, line)
    end
  end

  #Parses the body based on given headers and saves it to the result-object.
  # http.parse_body(str)
  def parse_body(line)
    return :break if @length == 0

    if @transfer_encoding == "chunked"
      return parse_body_chunked(line)
    else
      puts "Http2: Adding #{line.to_s.bytesize} to the body." if @debug
      @response.body << line
      @http2.on_content_call(@args, line)
      return :break if @response.content_length && @response.body.length >= @response.content_length
    end
  end

  def parse_body_chunked(line)
    len = line.strip.hex

    if len > 0
      read = @conn.read(len)
      return :break if read == "" || read == "\n" || read == "\r\n"
      @response.body << read
      @http2.on_content_call(@args, read)
    end

    nl = @conn.gets
    if len == 0
      if nl == "\n" || nl == "\r\n"
        return :break
      else
        raise "Dont know what to do :'-("
      end
    end

    raise "Should have read newline but didnt: '#{nl}'." if nl != @nl
  end
end
