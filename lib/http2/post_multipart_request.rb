require "tempfile"

class Http2::PostMultipartRequest
  attr_reader :headers_string

  def initialize(http2, *args)
    @http2, @nl, @args = http2, http2.nl, http2.parse_args(*args)
    @phash = @args[:post].clone
    @http2.autostate_set_on_post_hash(phash) if @http2.autostate
    @boundary = rand(36**50).to_s(36)
    @conn = @http2.connection
  end

  def execute
    generate_raw(@phash) do |helper, praw|
      @http2.mutex.synchronize do
        @conn.write(header_string_with_raw_post(praw))

        praw.rewind
        praw.each_line do |data|
          @conn.sock_write(data)
        end

        return @http2.read_response(self, @args)
      end
    end
  end

private

  def header_string_with_raw_post(praw)
    @headers_string = "POST /#{@args[:url]} HTTP/1.1#{@nl}"
    @headers_string << @http2.header_str(@http2.default_headers(@args).merge(
      "Content-Type" => "multipart/form-data; boundary=#{@boundary}",
      "Content-Length" => praw.size
    ), @args)
    @headers_string << @nl
    @headers_string
  end

  def generate_raw(phash)
    Tempfile.open("http2_post_multipart_tmp_#{@boundary}") do |praw|
      phash.each do |key, val|
        add_headers(praw, key, val)
        add_body(praw, val)
      end

      praw << "--#{@boundary}--"

      yield self, praw
    end
  end

  def read_file(path, praw)
    File.open(path, "r") do |fp|
      begin
        while data = fp.sysread(4096)
          praw << data
        end
      rescue EOFError
        # Happens when done.
      end
    end
  end

  def parse_temp_file(key, val, praw)
    praw << "Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{val.original_filename}\";#{@nl}"
    praw << "Content-Length: #{val.to_s.bytesize}#{@nl}"
  end

  def parse_file(key, val, praw)
    praw << "Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{val[:filename]}\";#{@nl}"

    if val[:content]
      praw << "Content-Length: #{val[:content].to_s.bytesize}#{@nl}"
    elsif val[:fpath]
      praw << "Content-Length: #{File.size(val[:fpath])}#{@nl}"
    else
      raise "Could not figure out where to get content from."
    end
  end

  def add_headers(praw, key, val)
    praw << "--#{@boundary}#{@nl}"

    if val.is_a?(Tempfile) && val.respond_to?(:original_filename)
      parse_temp_file(key, val, praw)
    elsif val.is_a?(Hash) && val[:filename]
      parse_file(key, val, praw)
    else
      praw << "Content-Disposition: form-data; name=\"#{key}\";#{@nl}"
      praw << "Content-Length: #{val.to_s.bytesize}#{@nl}"
    end

    praw << "Content-Type: text/plain#{@nl}"
    praw << @nl
  end

  def add_body(praw, val)
    if val.class.name.to_s == "StringIO"
      praw << val.read
    elsif val.is_a?(Hash) && val[:content]
      praw << val[:content].to_s
    elsif val.is_a?(Hash) && val[:fpath]
      read_file(val[:fpath], praw)
    else
      praw << val.to_s
    end

    praw << @nl
  end
end
