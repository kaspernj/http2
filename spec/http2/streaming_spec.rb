require "spec_helper"

describe Http2 do
  it "should stream to queue" do
    with_http do |http|
      result = http.get(url: "json_streaming.json", async: true, body_as: :buffer)

      result.buffer do |buffer|
        buffer.gets.should eq "{\n"
        buffer.gets.should eq "  \"Results:\" [\n"
        buffer.gets.should eq '    {"id": 1, "name":"Kasper"},' + "\n"
        buffer.gets.should eq '    {"id": 2, "name":"Christina"}' + "\n"
        buffer.gets.should eq "  ]\n"
        buffer.gets.should eq "}"
      end
    end
  end

  it "should stream json results" do
    with_http do |http|
      result = http.get(url: "json_streaming.json", async: true)

      puts "Running free - wee!"

      result.json_streaming_results do |result|
        puts "Result: #{result}"
      end
    end
  end
end
