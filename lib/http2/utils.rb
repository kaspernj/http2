# This class holds various methods for encoding, decoding and parsing of HTTP-related stuff.
class Http2::Utils
  # URL-encodes a string.
  def self.urlenc(string)
    # Thanks to CGI framework
    string.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/) do
      "%" + Regexp.last_match(1).unpack("H2" * Regexp.last_match(1).bytesize).join("%").upcase
    end.tr(" ", "+")
  end

  # URL-decodes a string.
  def self.urldec(string)
    # Thanks to CGI framework
    string.to_s.tr("+", " ").gsub(/((?:%[0-9a-fA-F]{2})+)/) do
      [Regexp.last_match(1).delete("%")].pack("H*")
    end
  end

  # Parses a cookies-string and returns them in an array.
  def self.parse_set_cookies(str)
    str = str.to_s
    return [] if str.empty?

    cookie_start_regex = /^(.+?)=(.*?)(;\s*|$)/

    match = str.match(cookie_start_regex)
    raise "Could not match cookie: '#{str}'" unless match

    str.gsub!(cookie_start_regex, "")

    cookie_data = {
      name: urldec(match[1].to_s),
      value: urldec(match[2].to_s)
    }

    while (match = str.match(/(.+?)=(.*?)(;\s*|$)/))
      str = str.gsub(match[0], "")
      key = match[1].to_s.downcase
      value = match[2].to_s

      if key == "path" || key == "expires"
        cookie_data[key.to_sym] = value
      else
        cookie_data[key] = value
      end
    end

    cookie = Http2::Cookie.new(cookie_data)

    [cookie]
  end
end
