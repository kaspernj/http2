require "spec_helper"

describe Http2::PostDataGenerator do
  it "should be able to recursively parse post-data-hashes." do
    res = Http2::PostDataGenerator.new(
      "test1" => "test2"
    ).generate
    raise "Expected 'test1=test2' but got: '#{res}'." if res != "test1=test2"

    res = Http2::PostDataGenerator.new(
      "test1" => [1, 2, 3]
    ).generate
    raise "Expected 'test1%5B0%5D=1&test1%5B1%5D=2&test1%5B2%5D=3' but got: '#{res}'." if res != "test1%5B0%5D=1&test1%5B1%5D=2&test1%5B2%5D=3"

    res = Http2::PostDataGenerator.new(
      "test1" => {
        "order" => {
          [:Bnet_profile, "profile_id"] => 5
        }
      }
    ).generate
    raise "Expected 'test1%5Border%5D%5B%5B%3ABnet_profile%2C+%22profile_id%22%5D%5D=5' but got: '#{res}'." if res != "test1%5Border%5D%5B%5B%3ABnet_profile%2C+%22profile_id%22%5D%5D=5"
  end
end
