module Helpers
  def with_webserver
    require "hayabusa"
    hayabusa = Hayabusa.new(
      doc_root: "#{File.dirname(__FILE__)}/spec_root",
      port: 3005
    )
    hayabusa.start

    begin
      yield(hayabusa)
    ensure
      hayabusa.stop
    end
  end

  def with_http(args = {})
    with_webserver do |hayabusa|
      Http2.new(host: "localhost", port: hayabusa.port, encoding_gzip: false, **args) do |http|
        yield http
      end
    rescue Http2::Errors::Internalserver => e
      puts "Body of error-response: #{e.response.body}"
      raise e
    end
  end
end
