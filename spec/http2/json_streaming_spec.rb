require "spec_helper"

describe Http2 do
  it "should stream json results" do
    with_http do |http|
      result = http.get(url: "json_streaming.json", stream_json: true, skip_body: true)
      result.json_streaming_results do |result|
        puts "Result: #{result}"
      end
    end
  end
end
