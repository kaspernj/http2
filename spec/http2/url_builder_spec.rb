require "spec_helper"

describe Http2::UrlBuilder do
  describe "#build" do
    it "builds correctly" do
      ub = Http2::UrlBuilder.new
      ub.protocol = "https"
      ub.host = "www.github.com"
      ub.port = "443"
      ub.path = "index.php"
      ub.params["test"] = "true"
      ub.params["test2"] = "false"

      expect(ub.build).to eq "https://www.github.com:443/index.php?test=true&test2=false"
    end
  end
end
