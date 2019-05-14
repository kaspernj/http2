class Http2::UrlBuilder
  attr_accessor :host, :port, :protocol, :path, :params

  def initialize
    @params = {}
  end

  def build_params
    url_params = ""

    unless params.empty?
      first = true

      params.each do |key, val|
        if first
          first = false
        else
          url_params << "&"
        end

        url_params << Http2::Utils.urlenc(key)
        url_params << "="
        url_params << Http2::Utils.urlenc(val)
      end
    end

    url_params
  end

  def build_path_and_params
    url = path.to_s

    if params?
      url << "?"
      url << build_params
    end

    url
  end

  def build
    url = ""
    url << "#{protocol}://" if protocol

    if host
      url << host
      url << ":#{port}/" if port
    end

    url << build_path_and_params

    url
  end

  def params?
    @params.any?
  end
end
