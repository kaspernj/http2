require "spec_helper"

describe Http2::PostRequest do
  it "reads the headers from the request" do
    with_http do |http|
      res = http.post(url: "json_test.rhtml", json: {testkey: "testvalue"})
      headers = res.request.headers_string
      headers.should include "POST /json_test.rhtml"
    end
  end
end
