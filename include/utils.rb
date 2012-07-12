class Http2::Utils
  #URL-encodes a string.
  def self.urlenc(string)
    #Thanks to CGI framework
    string.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/) do
      '%' + $1.unpack('H2' * $1.bytesize).join('%').upcase
    end.tr(' ', '+')
  end
  
  #URL-decodes a string.
  def self.urldec(string)
    #Thanks to CGI framework
    str = string.to_s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/) do
      [$1.delete('%')].pack('H*')
    end
  end
end