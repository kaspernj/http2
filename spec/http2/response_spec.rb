require "spec_helper"

describe Http2::Response do
  it "should register content type" do
    with_http do |http|
      res = http.get("content_type_test.rhtml")
      res.content_type.should eq "text/html"
    end
  end

  it "should register content length" do
    with_http do |http|
      res = http.get("content_type_test.rhtml")
      res.content_length.should > 50
    end
  end
end
