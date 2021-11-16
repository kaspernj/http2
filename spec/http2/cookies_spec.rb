require "spec_helper"

describe Http2::Cookie do
  include Helpers

  it "parses cookies and let them be read" do
    with_http do |http|
      http.get("cookie_test.rhtml")
      expect(http.cookies.length).to eq 2

      cookie = http.cookie("TestCookie")
      expect(cookie.name).to eq "TestCookie"
      expect(cookie.value).to eq "TestValue"
      expect(cookie.path).to eq "/"
      expect(cookie.expires).to be > Time.now
    end
  end
end
