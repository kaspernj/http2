class Http2::BaseRequest
  attr_reader :http2, :args, :debug

  VALID_ARGUMENTS_POST = [:post, :url, :default_headers, :headers, :json, :method, :cookies, :on_content, :content_type].freeze

  def initialize(http2, args)
    @http2 = http2
    @args = http2.parse_args(args)
    @debug = http2.debug
    @nl = http2.nl

    @args.each_key do |key|
      raise "Invalid key: '#{key}'." unless VALID_ARGUMENTS_POST.include?(key)
    end

    @conn = @http2.connection
  end

  def path
    @args.fetch(:url)
  end
end
