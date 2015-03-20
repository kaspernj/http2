require "spec_helper"

describe Http2 do
  it "should stream to queue" do
    with_http do |http|
      result = http.get(url: "json_streaming.json", async: true, body_as: :buffer)

      result.buffer do |buffer|
        buffer.gets.should eq "{\n"
        buffer.gets.should eq '  "Results": ' + "[\n"
        buffer.gets.should eq '    {"id": 1, "name":"Kasper"},' + "\n"
        buffer.gets.should eq '    {"id": 2, "name":"Christina"}' + "\n"
        buffer.gets.should eq "  ]\n"
        buffer.gets.should eq "}"
      end
    end
  end

  it "should stream json results" do
    with_http(debug: true) do |http|
      result = http.get(url: "json_streaming.json", async: true, body_as: :buffer)
      result.buffer do |buffer|
        require "json_streamer"

        parser = Yajl::Parser.new(symbolize_keys: true)
        parser.on_parse_complete = lambda { |obj|
          puts "ObjectParsed: #{obj}"
        }

        buffer.each_line do |line|
          puts "Giving line to parser: #{line}"
          parser << line
        end

        # hash = Yajl::Parser.parse(buffer)
      end
    end
  end
end
