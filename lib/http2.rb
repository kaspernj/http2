require "socket"
require "uri"
require "monitor" unless ::Kernel.const_defined?(:Monitor)
require "string-cases"

#This class tries to emulate a browser in Ruby without any visual stuff. Remember cookies, keep sessions alive, reset connections according to keep-alive rules and more.
#===Examples
# Http2.new(:host => "www.somedomain.com", :port => 80, :ssl => false, :debug => false) do |http|
#  res = http.get("index.rhtml?show=some_page")
#  html = res.body
#  print html
#
#  res = res.post("index.rhtml?choice=login", {"username" => "John Doe", "password" => 123})
#  print res.body
#  print "#{res.headers}"
# end
class Http2
  #Autoloader for subclasses.
  def self.const_missing(name)
    require "#{File.dirname(__FILE__)}/../include/#{::StringCases.camel_to_snake(name)}.rb"
    return Http2.const_get(name)
  end

  #Converts a URL to "is.gd"-short-URL.
  def self.isgdlink(url)
    Http2.new(:host => "is.gd") do |http|
      resp = http.get("/api.php?longurl=#{url}")
      return resp.body
    end
  end

  attr_reader :autostate, :cookies, :args, :debug, :mutex, :resp, :raise_errors, :nl
  attr_accessor :keepalive_max, :keepalive_timeout

  VALID_ARGUMENTS_INITIALIZE = [:host, :port, :ssl, :nl, :user_agent, :raise_errors, :follow_redirects, :debug, :encoding_gzip, :autostate, :basic_auth, :extra_headers, :proxy]
  def initialize(args = {})
    @args = parse_init_args(args)
    set_default_values
    @cookies = {}
    @mutex = Monitor.new
    self.reconnect

    if block_given?
      begin
        yield(self)
      ensure
        self.destroy
      end
    end
  end

  #Closes current connection if any, changes the arguments on the object and reconnects keeping all cookies and other stuff intact.
  def change(args)
    self.close
    @args.merge!(args)
    self.reconnect
  end

  #Closes the current connection if any.
  def close
    @sock.close if @sock and !@sock.closed?
    @sock_ssl.close if @sock_ssl and !@sock_ssl.closed?
    @sock_plain.close if @sock_plain and !@sock_plain.closed?
  end

  #Returns boolean based on the if the object is connected and the socket is working.
  #===Examples
  # puts "Socket is working." if http.socket_working?
  def socket_working?
    return false if !@sock or @sock.closed?

    if @keepalive_timeout and @request_last
      between = Time.now.to_i - @request_last.to_i
      if between >= @keepalive_timeout
        puts "Http2: We are over the keepalive-wait - returning false for socket_working?." if @debug
        return false
      end
    end

    return true
  end

  #Destroys the object unsetting all variables and closing all sockets.
  #===Examples
  # http.destroy
  def destroy
    @args = nil
    @cookies = nil
    @debug = nil
    @mutex = nil
    @uagent = nil
    @keepalive_timeout = nil
    @request_last = nil

    @sock.close if @sock and !@sock.closed?
    @sock = nil

    @sock_plain.close if @sock_plain and !@sock_plain.closed?
    @sock_plain = nil

    @sock_ssl.close if @sock_ssl and !@sock_ssl.closed?
    @sock_ssl = nil
  end

  #Reconnects to the host.
  def reconnect
    puts "Http2: Reconnect." if @debug

    #Open connection.
    if @args[:proxy] && @args[:ssl]
      connect_proxy_ssl
    elsif @args[:proxy]
      connect_proxy
    else
      print "Http2: Opening socket connection to '#{@args[:host]}:#{@args[:port]}'.\n" if @debug
      @sock_plain = TCPSocket.new(@args[:host], @args[:port].to_i)
    end

    if @args[:ssl]
      apply_ssl
    else
      @sock = @sock_plain
    end
  end

  #Forces various stuff into arguments-hash like URL from original arguments and enables single-string-shortcuts and more.
  def parse_args(*args)
    if args.length == 1 && args.first.is_a?(String)
      args = {:url => args.first}
    elsif args.length >= 2
      raise "Couldnt parse arguments."
    elsif args.is_a?(Array) && args.length == 1
      args = args.first
    else
      raise "Invalid arguments: '#{args.class.name}'."
    end

    if args[:url].to_s.split("\n").length != 1
      raise "Invalid URL: '#{args[:url]}'."
    end

    return args
  end

  #Returns a result-object based on the arguments.
  #===Examples
  # res = http.get("somepage.html")
  # print res.body #=> <String>-object containing the HTML gotten.
  def get(args)
    ::Http2::GetRequest.new(self, args).execute
  end

  # Proxies the request to another method but forces the method to be "DELETE".
  def delete(args)
    if args[:json]
      return self.post(args.merge(:method => :delete))
    else
      return self.get(args.merge(:method => :delete))
    end
  end

  #Tries to write a string to the socket. If it fails it reconnects and tries again.
  def write(str)
    #Reset variables.
    @length = nil
    @encoding = nil
    self.reconnect if !self.socket_working?

    begin
      raise Errno::EPIPE, "The socket is closed." if !@sock || @sock.closed?
      self.sock_write(str)
    rescue Errno::EPIPE #this can also be thrown by puts.
      self.reconnect
      self.sock_write(str)
    end

    @request_last = Time.now
  end

  #Returns the default headers for a request.
  #===Examples
  # headers_hash = http.default_headers
  # print "#{headers_hash}"
  def default_headers(args = {})
    return args[:default_headers] if args[:default_headers]

    headers = {
      "Connection" => "Keep-Alive",
      "User-Agent" => @uagent
    }

    #Possible to give custom host-argument.
    host = args[:host] || @args[:host]
    port = args[:port] || @args[:port]

    headers["Host"] = host
    headers["Host"] << ":#{port}" unless port && [80, 443].include?(port.to_i)
    headers["Accept-Encoding"] = "gzip" if @args[:encoding_gzip]

    if @args[:basic_auth]
      require "base64" unless ::Kernel.const_defined?(:Base64)
      headers["Authorization"] = "Basic #{Base64.encode64("#{@args[:basic_auth][:user]}:#{@args[:basic_auth][:passwd]}").strip}"
    end

    headers.merge!(@args[:extra_headers]) if @args[:extra_headers]
    headers.merge!(args[:headers]) if args[:headers]
    return headers
  end

  #Posts to a certain page.
  #===Examples
  # res = http.post("login.php", {"username" => "John Doe", "password" => 123)
  def post(args)
    ::Http2::PostRequest.new(self, args).execute
  end

  #Posts to a certain page using the multipart-method.
  #===Examples
  # res = http.post_multipart("upload.php", {"normal_value" => 123, "file" => Tempfile.new(?)})
  def post_multipart(*args)
    ::Http2::PostMultipartRequest.new(self, *args).execute
  end

  def sock_write(str)
    str = str.to_s
    return nil if str.empty?
    count = @sock.write(str)
    raise "Couldnt write to socket: '#{count}', '#{str}'." if count <= 0
  end

  def sock_puts(str)
    self.sock_write("#{str}#{@nl}")
  end

  #Returns a header-string which normally would be used for a request in the given state.
  def header_str(headers_hash, args = {})
    headers_hash["Cookie"] = cookie_header_string

    headers_str = ""
    headers_hash.each do |key, val|
      headers_str << "#{key}: #{val}#{@nl}"
    end

    return headers_str
  end

  def cookie_header_string
    cstr = ""

    first = true
    @cookies.each do |cookie_name, cookie_data|
      cstr << "; " unless first
      first = false if first

      if cookie_data.is_a?(Hash)
        name = cookie_data["name"]
        value = cookie_data["value"]
      else
        name = cookie_name
        value = cookie_data
      end

      raise "Unexpected lines: #{value.lines.to_a.length}." if value.lines.to_a.length != 1
      cstr << "#{Http2::Utils.urlenc(name)}=#{Http2::Utils.urlenc(value)}"
    end

    return cstr
  end

  def on_content_call(args, str)
    args[:on_content].call(str) if args.key?(:on_content)
  end

  #Reads the response after posting headers and data.
  #===Examples
  # res = http.read_response
  def read_response(args = {})
    ::Http2::ResponseReader.new(
      http2: self,
      sock: @sock,
      args: args
    ).response
  end

private

  #Registers the states from a result.
  def autostate_register(res)
    puts "Http2: Running autostate-register on result." if @debug
    @autostate_values.clear

    res.body.to_s.scan(/<input type="hidden" name="__(EVENTTARGET|EVENTARGUMENT|VIEWSTATE|LASTFOCUS)" id="(.*?)" value="(.*?)" \/>/) do |match|
      name = "__#{match[0]}"
      id = match[1]
      value = match[2]

      puts "Http2: Registered autostate-value with name '#{name}' and value '#{value}'." if @debug
      @autostate_values[name] = Http2::Utils.urldec(value)
    end

    raise "No states could be found." if @autostate_values.empty?
  end

  #Sets the states on the given post-hash.
  def autostate_set_on_post_hash(phash)
    phash.merge!(@autostate_values)
  end

  def parse_init_args(args)
    args = {:host => args} if args.is_a?(String)
    raise "Arguments wasnt a hash." unless args.is_a?(Hash)

    args.each do |key, val|
      raise "Invalid key: '#{key}'." unless VALID_ARGUMENTS_INITIALIZE.include?(key)
    end

    raise "No host was given." unless args[:host]
    return args
  end

  def set_default_values
    @debug = @args[:debug]
    @autostate_values = {} if autostate
    @nl = @args[:nl] || "\r\n"

    if !@args[:port]
      if @args[:ssl]
        @args[:port] = 443
      else
        @args[:port] = 80
      end
    end

    if @args[:user_agent]
      @uagent = @args[:user_agent]
    else
      @uagent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)"
    end

    if !@args.key?(:raise_errors) || @args[:raise_errors]
      @raise_errors = true
    else
      @raise_errors = false
    end
  end

  def connect_proxy_ssl
    print "Http2: Initializing proxy stuff.\n" if @debug
    @sock_plain = TCPSocket.new(@args[:proxy][:host], @args[:proxy][:port])

    @sock_plain.write("CONNECT #{@args[:host]}:#{@args[:port]} HTTP/1.0#{@nl}")
    @sock_plain.write("User-Agent: #{@uagent}#{@nl}")

    if @args[:proxy][:user] and @args[:proxy][:passwd]
      credential = ["#{@args[:proxy][:user]}:#{@args[:proxy][:passwd]}"].pack("m")
      credential.delete!("\r\n")
      @sock_plain.write("Proxy-Authorization: Basic #{credential}#{@nl}")
    end

    @sock_plain.write(@nl)

    res = @sock_plain.gets
    raise res if res.to_s.downcase != "http/1.0 200 connection established#{@nl}"
  end

  def connect_proxy
    puts "Http2: Opening socket connection to '#{@args[:host]}:#{@args[:port]}' through proxy '#{@args[:proxy][:host]}:#{@args[:proxy][:port]}'." if @debug
    @sock_plain = TCPSocket.new(@args[:proxy][:host], @args[:proxy][:port].to_i)
  end

  def apply_ssl
    puts "Http2: Initializing SSL." if @debug
    require "openssl" unless ::Kernel.const_defined?(:OpenSSL)

    ssl_context = OpenSSL::SSL::SSLContext.new
    #ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

    @sock_ssl = OpenSSL::SSL::SSLSocket.new(@sock_plain, ssl_context)
    @sock_ssl.sync_close = true
    @sock_ssl.connect

    @sock = @sock_ssl
  end
end