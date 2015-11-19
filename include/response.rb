#This object will be returned as the response for each request.
class Http2::Response
  #All the data the response contains. Headers, body, cookies, requested URL and more.
  attr_reader :args, :request
  attr_accessor :body, :charset, :code, :content_type, :http_version

  #This method should not be called manually.
  def initialize(args = {})
    @args = args
    @args[:headers] ||= {}
    @body = args[:body] || ""
    @debug = args[:debug]
    @request = args.fetch(:request)
  end

  #Returns headers given from the host for the result.
  #===Examples
  # headers_hash = res.headers
  def headers
    return @args.fetch(:headers)
  end

  #Returns a certain header by name or false if not found.
  #===Examples
  # val = res.header("content-type")
  def header(key)
    return false unless @args.fetch(:headers).key?(key)
    return @args.fetch(:headers).fetch(key).first.to_s
  end

  #Returns true if a header of the given string exists.
  #===Examples
  # print "No content-type was given." if !http.header?("content-type")
  def header?(key)
    return true if @args[:headers].key?(key) && @args[:headers][key].first.to_s.length > 0
    return false
  end

  def content_length
    if header?("content-length")
      header("content-length").to_i
    elsif @body
      return @body.bytesize
    else
      raise "Couldn't calculate content-length."
    end
  end

  def content_type
    if header?("content-type")
      return header("content-type")
    else
      raise "No content-type was given."
    end
  end

  #Returns the requested URL as a string.
  #===Examples
  # res.requested_url #=> "?show=status&action=getstatus"
  def requested_url
    raise "URL could not be detected." unless @args[:request_args][:url]
    return @args[:request_args][:url]
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

private

  # Checks that the length of the body is the same as the given content-length if given.
  def validate_body_versus_content_length!
    unless self.header?("content-length")
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
