require "spec_helper"

describe Http2::PostMultipartRequest do
  it "reads the headers from the request" do
    with_http do |http|
      res = http.post_multipart(url: "json_test.rhtml", post: {"test1" => "test2"})
      headers = res.request.headers_string
      expect(headers).to include "POST /json_test.rhtml"
    end
  end
end
