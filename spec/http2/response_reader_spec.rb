require "spec_helper"

describe Http2::ResponseReader do
  it "#url_and_args_from_location" do
    with_http(ssl_skip_verify: true, follow_redirects: true) do |http|
      response = http.get("redirect_test.rhtml?redirect_to=https://www.google.dk")
      expect(response.host).to eq "www.google.dk"
      expect(response.ssl?).to be true
      expect(response.port).to eq 443
    end
  end
end
