require "spec_helper"

describe Http2::Response do
  it "should register content type" do
    Http2.new(host: "http2test.kaspernj.org") do |http|
      res = http.get("content_type_test.php")
      res.content_type.should eq "text/html"
    end
  end

  it "should register content length" do
    Http2.new(host: "http2test.kaspernj.org") do |http|
      res = http.get("content_type_test.php")
      res.content_length.should > 50
    end
  end
end
