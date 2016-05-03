require "spec_helper"
require "json"

describe "Http2" do
  it "should be able to do normal post-requests." do
    # Test posting keep-alive and advanced post-data.
    with_http do |http|
      0.upto(5) do
        http.get("multipart_test.rhtml")

        resp = http.post(
          url: "multipart_test.rhtml?choice=post-test",
          post: {
            "val1" => "test1",
            "val2" => "test2",
            "val3" => [
              "test3"
            ],
            "val4" => {
              "val5" => "test5"
            },
            "val6" => {
              "val7" => [
                {
                  "val8" => "test8"
                }
              ]
            },
            "val9" => ["a", "b", "d"]
          }
        )
        res = JSON.parse(resp.body)

        expect(res.is_a?(Hash)).to eq true
        expect(res["val1"]).to eq "test1"
        expect(res["val2"]).to eq "test2"
        expect(res["val3"]["0"]).to eq "test3"
        expect(res["val4"]["val5"]).to eq "test5"
        expect(res["val6"]["val7"]["0"]["val8"]).to eq "test8"
        expect(res["val9"]["0"]).to eq "a"
        expect(res["val9"]["1"]).to eq "b"
        expect(res["val9"]["2"]).to eq "d"
      end
    end
  end

  it "#reconnect" do
    with_http(follow_redirects: false, encoding_gzip: false) do |http|
      resp1 = http.get("multipart_test.rhtml")
      http.reconnect
      resp2 = http.get("multipart_test.rhtml")

      expect(resp1.body).to eq resp2.body
    end
  end

  it "should be able to do multipart-requests and keep-alive when using multipart." do
    with_http(follow_redirects: false) do |http|
      0.upto(5) do
        fpath = File.realpath(__FILE__)
        fpath2 = "#{File.realpath(File.dirname(__FILE__))}/../lib/http2.rb"

        resp = http.post_multipart(
          url: "multipart_test.rhtml",
          post: {
            "test_var" => "true",
            "test_file1" => {
              fpath: fpath,
              filename: "specfile"
            },
            "test_file2" => {
              fpath: fpath2,
              filename: "http2.rb"
            }
          }
        )

        data = JSON.parse(resp.body)

        expect(data["post"]["test_var"]).to eq "true"
        expect(data["files_data"]["test_file1"]).to eq File.read(fpath)
        expect(data["files_data"]["test_file2"]).to eq File.read(fpath2)
      end
    end
  end

  it "it should be able to handle keep-alive correctly" do
    urls = [
      "content_type_test.rhtml",
      "json_test.rhtml"
    ]

    with_http do |http|
      0.upto(105) do |_count|
        url = urls[rand(urls.size)]
        # puts "Doing request #{count} of 200 (#{url})."
        res = http.get(url)
        expect(res.body.to_s.length).to be > 0
      end
    end
  end

  it "should be able to convert URL's to 'is.gd'-short-urls" do
    isgd = Http2.isgdlink("https://github.com/kaspernj/http2")
    raise "Expected isgd-var to be valid but it wasnt: '#{isgd}'." unless isgd.match(/^http:\/\/is\.gd\/([A-z\d]+)$/)
  end

  it "should raise exception when something is not found" do
    with_http do |http|
      expect { http.get("something_that_does_not_exist.rhtml") }.to raise_error(::Http2::Errors::Notfound)
    end
  end

  it "should be able to post json" do
    with_http do |http|
      res = http.post(
        url: "json_test.rhtml",
        json: {testkey: "testvalue"}
      )

      data = JSON.parse(res.body)
      expect(data["_SERVER"]["HTTP_CONTENT_TYPE"]).to eq "application/json"

      # Hack JSON data from Hayabusa.
      json_data = JSON.parse(data["_POST"].keys.first)
      expect(json_data["testkey"]).to eq "testvalue"

      expect(res.content_type).to eq "application/json"
      expect(res.json?).to eq true
      expect(res.json["_SERVER"]["REQUEST_METHOD"]).to eq "POST"
    end
  end

  it "should be able to post custom content types" do
    with_http do |http|
      res = http.post(
        url: "content_type_test.rhtml",
        content_type: "plain/text",
        post: "test1_test2_test3"
      )

      data = JSON.parse(res.body)
      expect(data["_SERVER"]["HTTP_CONTENT_TYPE"]).to eq "plain/text"

      raw_data = data["_POST"].keys.first
      expect(raw_data).to eq "test1_test2_test3"
    end
  end

  it "should set various timeouts" do
    with_http do |http|
      http.get("content_type_test.rhtml")
      expect(http.keepalive_timeout).to eq 15
      expect(http.keepalive_max).to eq 30
    end
  end

  it "should follow redirects" do
    with_http(follow_redirects: true) do |http|
      resp = http.get("redirect_test.rhtml")
      expect(resp.code).to eq "200"
    end
  end

  it "throws errors on unauhtorized" do
    with_http do |http|
      expect do
        http.get("unauthorized.rhtml")
      end.to raise_error(Http2::Errors::Unauthorized)
    end
  end
end
