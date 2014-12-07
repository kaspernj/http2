#This object will be returned as the response for each request.
class Http2::Response
  #All the data the response contains. Headers, body, cookies, requested URL and more.
  attr_reader :args, :tempfile, :buffer
  attr_accessor :body, :charset, :code, :content_type, :http_version

  #This method should not be called manually.
  def initialize(args = {})
    @args = args
    @args[:headers] = {} unless @args.key?(:headers)
    @debug = @args[:debug]

    if args[:request_args][:args][:body_as] == :tempfile
      @tempfile = Tempfile.new
    elsif args[:request_args][:args][:body_as] == :buffer
      require "thread_queues"
      @queue = ThreadQueues::BufferedQueue.new(50)
      @buffer = ThreadQueues::StringBuffer.new(@queue)
    else
      @body = ""
    end
  end

  def buffer
    if @buffer
      if block_given?
        begin
          yield @buffer
        ensure
          @queue.close
        end
      else
        return @buffer
      end
    else
      raise "Not in buffer-mode"
    end
  end

  def tempfile
    if @tempfile
      return @tempfile
    else
      raise "Not in tempfile-mode"
    end
  end

  def body
    if body?
      return @body
    else
      raise "Not in body-mode"
    end
  end

  def body?
    return true if @body
  end

  def finish
    @queue.close if @queue
  end

  #Returns headers given from the host for the result.
  #===Examples
  # headers_hash = res.headers
  def headers
    return @args[:headers]
  end

  #Returns a certain header by name or false if not found.
  #===Examples
  # val = res.header("content-type")
  def header(key)
    return false if !@args[:headers].key?(key)
    return @args[:headers][key].first.to_s
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

  def content_length?
    if header?("content-length")
      return true
    elsif @body
      return true
    end

    return false
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
    @http2.debug "Validating response length." if @debug
    validate_body_versus_content_length!
  end

  def add_to_body(obj)
    if @tempfile
      @tempfile.write(obj)
    elsif @queue
      @queue.push(obj)
    elsif @body
      @body << obj
    else
      raise "Don't know how to add to body?"
    end
  end

private

  # Checks that the length of the body is the same as the given content-length if given.
  def validate_body_versus_content_length!
    unless self.header?("content-length")
      @http2.debug "No content length given - skipping length validation." if @debug
      return nil
    end

    if @body
      body_length = @body.bytesize
    elsif @tempfile
      body_length File.size(@tempfile.path)
    end

    if body_length
      content_length = header("content-length").to_i

      @http2.debug "Body length: #{body_length}" if @debug
      @http2.debug "Content length: #{content_length}" if @debug

      if body_length != content_length
        raise "Body does not match the given content-length: '#{body_length}', '#{content_length}'."
      end
    end
  end
end
