require "spec_helper"
require "json"

describe "Http2" do
  it "should be able to do normal post-requests." do
    #Test posting keep-alive and advanced post-data.
    Http2.new(host: "www.partyworm.dk", debug: false) do |http|
      0.upto(5) do
        resp = http.get("multipart_test.php")

        resp = http.post(url: "multipart_test.php?choice=post-test", post: {
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
        })
        res = JSON.parse(resp.body)

        res.is_a?(Hash).should eq true
        res["val1"].should eq "test1"
        res["val2"].should eq "test2"
        res["val3"][0].should eq "test3"
        res["val4"]["val5"].should eq "test5"
        res["val6"]["val7"][0]["val8"].should eq "test8"
        res["val9"][0].should eq "a"
        res["val9"][1].should eq "b"
        res["val9"][2].should eq "d"
      end
    end
  end

  it "#reconnect" do
    Http2.new(host: "www.partyworm.dk", follow_redirects: false, encoding_gzip: false, debug: false) do |http|
      resp1 = http.get("multipart_test.php")
      http.reconnect
      resp2 = http.get("multipart_test.php")

      resp1.body.should eq resp2.body
    end
  end

  it "should be able to do multipart-requests and keep-alive when using multipart." do
    Http2.new(host: "www.partyworm.dk", follow_redirects: false, encoding_gzip: false, debug: false) do |http|
      0.upto(5) do
        fpath = File.realpath(__FILE__)
        fpath2 = "#{File.realpath(File.dirname(__FILE__))}/../lib/http2.rb"

        resp = http.post_multipart(url: "multipart_test.php", post: {
          "test_var" => "true",
          "test_file1" => {
            fpath: fpath,
            filename: "specfile"
          },
          "test_file2" => {
            fpath: fpath2,
            filename: "http2.rb"
          }
        })

        data = JSON.parse(resp.body)

        data["post"]["test_var"].should eq "true"
        data["files_data"]["test_file1"].should eq File.read(fpath)
        data["files_data"]["test_file2"].should eq File.read(fpath2)
      end
    end
  end

  it "it should be able to handle keep-alive correctly" do
    urls = [
      "?show=users_search",
      "?show=users_online",
      "?show=drinksdb",
      "?show=forum&fid=9&tid=1917&page=0"
    ]
    urls = ["robots.txt"]

    Http2.new(host: "www.partyworm.dk", debug: false) do |http|
      0.upto(105) do |count|
        url = urls[rand(urls.size)]
        #print "Doing request #{count} of 200 (#{url}).\n"
        res = http.get(url)
        res.body.to_s.length.should > 0
      end
    end
  end

  it "should be able to convert URL's to 'is.gd'-short-urls" do
    isgd = Http2.isgdlink("https://github.com/kaspernj/http2")
    raise "Expected isgd-var to be valid but it wasnt: '#{isgd}'." if !isgd.match(/^http:\/\/is\.gd\/([A-z\d]+)$/)
  end

  it "should raise exception when something is not found" do
    expect{
      Http2.new(host: "www.partyworm.dk") do |http|
        http.get("something_that_does_not_exist.php")
      end
    }.to raise_error(::Http2::Errors::Notfound)
  end

  it "should be able to post json" do
    Http2.new(host: "http2test.kaspernj.org") do |http|
      res = http.post(
        url: "/jsontest.php",
        json: {testkey: "testvalue"}
      )

      data = JSON.parse(res.body)
      data["_SERVER"]["CONTENT_TYPE"].should eql("application/json")
      data["PHP_JSON_INPUT"]["testkey"].should eql("testvalue")
    end
  end

  it "should be able to post custom content types" do
    require "json"

    Http2.new(host: "http2test.kaspernj.org") do |http|
      res = http.post(
        url: "content_type_test.php",
        content_type: "plain/text",
        post: "test1_test2_test3"
      )

      data = JSON.parse(res.body)
      data["_SERVER"]["CONTENT_TYPE"].should eql("plain/text")
      data["PHP_INPUT"].should eql("test1_test2_test3")
    end
  end

  it "should set various timeouts" do
    Http2.new(host: "http2test.kaspernj.org") do |http|
      res = http.get("content_type_test.php")
      http.keepalive_timeout.should eq 5
      http.keepalive_max.should eq 100
    end
  end

  it "should follow redirects" do
    Http2.new(host: "http2test.kaspernj.org", follow_redirects: true) do |http|
      resp = http.get("redirect_test.php")
      resp.code.should eq "200"
    end
  end
end
