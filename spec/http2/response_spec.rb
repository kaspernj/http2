require "spec_helper"

describe Http2::Response do
  it "#content_type" do
    with_http do |http|
      res = http.get("content_type_test.rhtml")
      expect(res.content_type).to eq "text/html"
    end
  end

  it "#content_length" do
    with_http do |http|
      res = http.get("content_type_test.rhtml")
      expect(res.content_length).to be > 50
    end
  end

  describe "#json?" do
    it "returns true for 'application/json'" do
      with_http do |http|
        res = http.get("json_test.rhtml")

        expect(res).to receive(:content_type).and_return("application/json")
        expect(res.json?).to eq true
      end
    end

    it "returns true for 'application/json'" do
      with_http do |http|
        res = http.get("json_test.rhtml")
        expect(res.json?).to eq true
      end
    end

    it "returns true for 'application/json'" do
      with_http do |http|
        res = http.post(url: "json_test.rhtml", post: {test: "test2"})

        expect(res).to receive(:content_type).and_return("application/json; charset=utf-8")
        expect(res.json["_POST"]).to eq("test" => "test2")
      end
    end
  end

  it "#host" do
    with_http do |http|
      res = http.get("json_test.rhtml")
      expect(res.host).to eq "localhost"
    end
  end

  it "#port" do
    with_http do |http|
      res = http.get("json_test.rhtml")
      expect(res.port).to eq http.port
    end
  end

  it "#ssl?" do
    with_http do |http|
      res = http.get("json_test.rhtml")
      expect(res.ssl?).to eq false
    end
  end

  it "#path" do
    with_http do |http|
      res = http.get("json_test.rhtml")
      expect(res.path).to eq "json_test.rhtml"
    end
  end

  it "#header" do
    with_http do |http|
      res = http.get("json_test.rhtml")
      expect(res.header("connection")).to eq "Keep-Alive"
    end
  end

  it "#header?" do
    with_http do |http|
      res = http.get("json_test.rhtml")
      expect(res.header?("connection")).to eq true
    end
  end

  it "#json" do
    with_http do |http|
      res = http.post(url: "json_test.rhtml", post: {test: "test2"})
      expect(res.json["_POST"]).to eq("test" => "test2")
    end
  end
end
