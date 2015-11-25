class Http2::Connection
  def initialize(http2)
    @http2, @debug, @args, @nl = http2, http2.debug, http2.args, http2.nl
    reconnect
  end

  def destroy
    @sock.close if @sock && !@sock.closed?
    @sock = nil

    @sock_plain.close if @sock_plain && !@sock_plain.closed?
    @sock_plain = nil

    @sock_ssl.close if @sock_ssl && !@sock_ssl.closed?
    @sock_ssl = nil
  end

  def gets
    @sock.gets
  end

  def read(length)
    @sock.read(length)
  end

  def close
    @sock.close
  end

  def closed?
    @sock.closed?
  end

  def sock_write(str)
    str = str.to_s
    return if str.empty?
    count = @sock.write(str)
    raise "Couldnt write to socket: '#{count}', '#{str}'." if count <= 0
  end

  def sock_puts(str)
    sock_write("#{str}#{@nl}")
  end

  # Tries to write a string to the socket. If it fails it reconnects and tries again.
  def write(str)
    reconnect unless socket_working?

    puts "Http2: Writing: #{str}" if @debug

    begin
      raise Errno::EPIPE, "The socket is closed." if !@sock || @sock.closed?
      sock_write(str)
    rescue Errno::EPIPE #this can also be thrown by puts.
      reconnect
      sock_write(str)
    end

    @request_last = Time.now
  end

  # Reconnects to the host.
  def reconnect
    puts "Http2: Reconnect." if @debug

    #Open connection.
    if @args[:proxy]
      if @args[:proxy][:connect]
        connect_proxy_connect
      else
        connect_proxy
      end
    else
      puts "Http2: Opening socket connection to '#{@http2.host}:#{@http2.port}'." if @debug
      @sock_plain = TCPSocket.new(@http2.host, @http2.port)
    end

    if @args[:ssl]
      apply_ssl
    else
      @sock = @sock_plain
    end
  end

  # Returns boolean based on the if the object is connected and the socket is working.
  #===Examples
  # puts "Socket is working." if http.socket_working?
  def socket_working?
    return false if !@sock or @sock.closed?

    if @keepalive_timeout && @request_last
      between = Time.now.to_i - @request_last.to_i
      if between >= @keepalive_timeout
        puts "Http2: We are over the keepalive-wait - returning false for socket_working?." if @debug
        return false
      end
    end

    return true
  end

  # Closes the current connection if any.
  def close
    @sock.close if @sock && !@sock.closed?
    @sock_ssl.close if @sock_ssl && !@sock_ssl.closed?
    @sock_plain.close if @sock_plain && !@sock_plain.closed?
  end

  def connect_proxy_connect
    puts "Http2: Initializing proxy connect to '#{@args[:host]}:#{@args[:port]}' through proxy '#{@args[:proxy][:host]}:#{@args[:proxy][:port]}'." if @debug
    @sock_plain = TCPSocket.new(@args[:proxy][:host], @args[:proxy][:port])

    connect = "CONNECT #{@args[:host]}:#{@args[:port]} HTTP/1.1#{@nl}"
    puts "Http2: Sending connect: #{connect}" if @debug
    @sock_plain.write(connect)

    headers = {
      "Host" => "#{@args[:host]}:#{@args[:port]}"
    }

    if @args[:proxy][:user] && @args[:proxy][:passwd]
      headers["Proxy-Authorization"] = "Basic #{["#{@args[:proxy][:user]}:#{@args[:proxy][:passwd]}"].pack("m").chomp}"
    end

    headers.each do |key, value|
      header = "#{key}: #{value}"
      puts "Http2: Sending header to proxy: #{header}" if @debug
      @sock_plain.write("#{header}#{@nl}")
    end

    @sock_plain.write(@nl)

    res = @sock_plain.gets.to_s
    raise "Couldn't connect through proxy: #{res}" unless res.match(/^http\/1\.(0|1)\s+200/i)
    @sock_plain.gets

    @proxy_connect = true
  end

  def proxy_connect?
    @proxy_connect
  end

  def connect_proxy
    puts "Http2: Opening socket connection to '#{@args[:host]}:#{@args[:port]}' through proxy '#{@args[:proxy][:host]}:#{@args[:proxy][:port]}'." if @debug
    @sock_plain = TCPSocket.new(@args[:proxy][:host], @args[:proxy][:port].to_i)
  end

  def apply_ssl
    puts "Http2: Initializing SSL." if @debug
    require "openssl" unless ::Kernel.const_defined?(:OpenSSL)

    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER unless @args[:ssl_skip_verify]
    @sock_ssl = OpenSSL::SSL::SSLSocket.new(@sock_plain, ssl_context)
    @sock_ssl.sync_close = true
    @sock_ssl.connect

    @sock = @sock_ssl
  end
end
