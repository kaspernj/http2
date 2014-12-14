# http2

[![Build Status](https://api.shippable.com/projects/53bd3eef2e23bdcb03c0df9e/badge/master)](https://www.shippable.com/projects/53bd3eef2e23bdcb03c0df9e)
[![Code Climate](https://codeclimate.com/github/kaspernj/http2.png)](https://codeclimate.com/github/kaspernj/http2)
[![Code Climate](https://codeclimate.com/github/kaspernj/http2/coverage.png)](https://codeclimate.com/github/kaspernj/http2)

# Usage

```ruby
require "rubygems"
require "http2"

Http2.new(host: "www.google.dk") do |http|
  # Do requests here.
end
```

Or without using a block for ensuring closing of connection:
```ruby
http = Http2.new(...)

# Do requests here.

http.close
```

## Get requests
```ruby
res = http.get("path/to/something")
```

## Post requests
```ruby
res = http.post(url: "path/to/something", post: {
  "some_post_val" => "some_value"
})
```

## File upload
```ruby
res = http.post_multipart(url: "path/to/something", post: {
  "test_file1" => {
    fpath: fpath,
    filename: "specfile"
  }
})
```

## Reading cookies
```ruby
puts "Cookies until now: #{http.cookies}"
```

## Inspecting responses

```ruby
resp = http.get("path/to/something")
resp.content_type #=> "text/html"
resp.content_length #=> 136
resp.header("content-length") #=> "136"
resp.headers #=> {"content-type" => ["text/html"], "content-length" => ["136"]}
resp.code #=> "200"
resp.charset #=> "utf-8"
resp.http_version #=> "1.1"
resp.body #=> "<html><body>..."
resp.requested_url #=> "http://example.com/maybe/redirected/path/to/something"
```

## Get parameters later.

```ruby
http.host #=> example.com
http.port #=> 80
```


## Reconnect

Handy when doing retries.

```ruby
http.reconnect
```

## Contributing to http2

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012 Kasper Johansen. See LICENSE.txt for
further details.
