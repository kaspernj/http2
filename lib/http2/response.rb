# This object will be returned as the response for each request.
class Http2::Response
  # All the data the response contains. Headers, body, cookies, requested URL and more.
  attr_reader :headers, :request, :request_args, :requested_url
  attr_accessor :body, :charset, :code, :http_version

  # This method should not be called manually.
  def initialize(body: "", debug: false, headers: {}, request:)
    @body = body
    @debug = debug
    @headers = headers
    @request = request
    @requested_url = request.path
  end

  # Returns a certain header by name or false if not found.
  #===Examples
  # val = res.header("content-type")
  def header(key)
    return false unless headers.key?(key)

    headers.fetch(key).first.to_s
  end

  # Returns true if a header of the given string exists.
  #===Examples
  # print "No content-type was given." if !http.header?("content-type")
  def header?(key)
    return true if headers.key?(key) && !headers[key].first.to_s.empty?

    false
  end

  def content_length
    if header?("content-length")
      header("content-length").to_i
    elsif @body
      @body.bytesize
    else
      raise "Couldn't calculate content-length."
    end
  end

  def content_type
    if header?("content-type")
      header("content-type")
    else
      raise "No content-type was given."
    end
  end

  # Checks the data that has been sat on the object and raises various exceptions, if it does not validate somehow.
  def validate!
    puts "Http2: Validating response length." if @debug
    validate_body_versus_content_length!
  end

  # Returns true if the result is JSON.
  def json?
    content_type == "application/json"
  end

  def json
    @json ||= JSON.parse(body)
  end

  def host
    @request.http2.host
  end

  def port
    @request.http2.port
  end

  def ssl?
    @request.http2.ssl?
  end

  def path
    @request.path
  end

  def to_s
    "#<Http::Response host=\"#{host}\" port=#{port} ssl=#{ssl?} path=\"#{path}\">"
  end

  def inspect
    to_s
  end

private

  # Checks that the length of the body is the same as the given content-length if given.
  def validate_body_versus_content_length!
    unless header?("content-length")
      puts "Http2: No content length given - skipping length validation." if @debug
      return nil
    end

    content_length = header("content-length").to_i
    body_length = @body.bytesize

    puts "Http2: Body length: #{body_length}" if @debug
    puts "Http2: Content length: #{content_length}" if @debug

    raise "Body does not match the given content-length: '#{body_length}', '#{content_length}'." if body_length != content_length
  end
end
