require "tempfile"

class Http2::PostMultipartHelper
  attr_reader :boundary

  def initialize(http2)
    @nl = http2.nl

    #Generate random string.
    @boundary = rand(36**50).to_s(36)
  end

  def generate_raw(phash)
    Tempfile.open("http2_post_multipart_tmp_#{@boundary}") do |praw|
      phash.each do |key, val|
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
end
