require "spec_helper"

describe Http2::GetRequest do
  it "reads the headers from the request" do
    with_http do |http|
      res = http.get("content_type_test.rhtml")
      headers = res.request.headers_string
      headers.should include "GET /content_type_test.rhtml"
    end
  end
end
