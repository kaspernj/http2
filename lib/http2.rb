require "socket"
require "uri"
require "monitor" unless ::Kernel.const_defined?(:Monitor)
require "string-cases"

#This class tries to emulate a browser in Ruby without any visual stuff. Remember cookies, keep sessions alive, reset connections according to keep-alive rules and more.
#===Examples
# Http2.new(host: "www.somedomain.com", port: 80, ssl: false, debug: false) do |http|
#  res = http.get("index.rhtml?show=some_page")
#  html = res.body
#  print html
#
#  res = res.post("index.rhtml?choice=login", {"username" => "John Doe", "password" => 123})
#  print res.body
#  print "#{res.headers}"
# end
class Http2
  # Autoloader for subclasses.
  def self.const_missing(name)
    require "#{File.dirname(__FILE__)}/../include/#{::StringCases.camel_to_snake(name)}.rb"
    return Http2.const_get(name)
  end

  # Converts a URL to "is.gd"-short-URL.
  def self.isgdlink(url)
    Http2.new(host: "is.gd") do |http|
      resp = http.get("/api.php?longurl=#{url}")
      return resp.body
    end
  end

  attr_reader :autostate, :connection, :cookies, :args, :mutex, :resp, :raise_errors, :nl
  attr_accessor :keepalive_max, :keepalive_timeout

  VALID_ARGUMENTS_INITIALIZE = [:host, :port, :skip_port_in_host_header, :ssl, :nl, :user_agent, :raise_errors, :follow_redirects, :debug, :encoding_gzip, :autostate, :basic_auth, :extra_headers, :proxy]
  def initialize(args = {})
    @args = parse_init_args(args)
    set_default_values
    @cookies = {}
    @mutex = Monitor.new

    @connection = ::Http2::Connection.new(self)

    if block_given?
      begin
        yield(self)
      ensure
        self.destroy
      end
    end
  end

  def host
    @args[:host]
  end

  def port
    @args[:port]
  end

  def reconnect
    @connection.reconnect
  end

  def new_url
    builder = Http2::UrlBuilder.new
    builder.host = host
    builder.port = port
    builder.protocol = @args[:protocol]

    return builder
  end

  # Closes current connection if any, changes the arguments on the object and reconnects keeping all cookies and other stuff intact.
  def change(args)
    @args.merge!(args)
    @connection.destroy
    @connection = ::Http2::Connection.new(self)
  end

  #Destroys the object unsetting all variables and closing all sockets.
  #===Examples
  # http.destroy
  def destroy
    @connection.destroy
    @connection = nil
  end

  def debug(message)
    print "Http2: #{message}\n" if @debug
  end

  def debug?
    return @debug
  end

  #Forces various stuff into arguments-hash like URL from original arguments and enables single-string-shortcuts and more.
  def parse_args(*args)
    if args.length == 1 && args.first.is_a?(String)
      args = {url: args.first}
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
      return post(args.merge(method: :delete))
    else
      return get(args.merge(method: :delete))
    end
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
    host = args[:host] || self.host
    port = args[:port] || self.port

    headers["Host"] = "#{host}" # Copy host string to avoid changing the original string if port has been given!
    headers["Host"] << ":#{port}" if port && ![80, 443].include?(port.to_i) && !@args[:skip_port_in_host_header]
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
    response_reader = ::Http2::ResponseReader.new(http2: self, sock: @sock, args: args)

    if args[:async]
      Thread.new do
        Thread.current.abort_on_exception = true
        response_reader.read
      end
    else
      response_reader.read
    end

    return response_reader.response
  end

  def to_s
    "<Http2 host: #{host}:#{port}>"
  end

  def inspect
    to_s
  end

private

  #Registers the states from a result.
  def autostate_register(res)
    debug "Running autostate-register on result." if @debug
    @autostate_values.clear

    res.body.to_s.scan(/<input type="hidden" name="__(EVENTTARGET|EVENTARGUMENT|VIEWSTATE|LASTFOCUS)" id="(.*?)" value="(.*?)" \/>/) do |match|
      name = "__#{match[0]}"
      id = match[1]
      value = match[2]

      debug "Registered autostate-value with name '#{name}' and value '#{value}'." if @debug
      @autostate_values[name] = Http2::Utils.urldec(value)
    end

    raise "No states could be found." if @autostate_values.empty?
  end

  #Sets the states on the given post-hash.
  def autostate_set_on_post_hash(phash)
    phash.merge!(@autostate_values)
  end

  def parse_init_args(args)
    args = {host: args} if args.is_a?(String)
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
end
