require "spec_helper"

describe Http2 do
  include Helpers

  it "should parse cookies and let them be read" do
    with_http do |http|
      res = http.get("cookie_test.rhtml")
      http.cookies.length.should eq 2

      cookie = http.cookie("TestCookie")
      cookie.name.should eq "TestCookie"
      cookie.value.should eq "TestValue"
      cookie.path.should eq "/"
      cookie.expires.should > Time.now
    end
  end
end
