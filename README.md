[![Build Status](https://api.shippable.com/projects/540e7b9b3479c5ea8f9ec21d/badge?branchName=master)](https://app.shippable.com/projects/540e7b9b3479c5ea8f9ec21d/builds/latest)
[![Code Climate](https://codeclimate.com/github/kaspernj/http2.png)](https://codeclimate.com/github/kaspernj/http2)
[![Code Climate](https://codeclimate.com/github/kaspernj/http2/coverage.png)](https://codeclimate.com/github/kaspernj/http2)

# http2

A HTTP-framework for Ruby supporting keep-alive, compression, JSON-posting, detailed inspection of responses and much more.

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

http.destroy # Closes the connection and frees up any variables used
```

Or through a proxy:
```ruby
Http2.new(host: "www.google.com", proxy: {host: "myproxy.com", port: 80, user: "myname", passwd: "mypassword"})
```

You can also use SSL:
```ruby
Http2.new(host: "myhost.com", ssl: true, ssl_skip_verify: true)
```

## Get requests
```ruby
res = http.get("path/to/something")
```

Or as a hash:
```ruby
res = http.get(url: "path/to/something")
```

## Post requests
```ruby
res = http.post(url: "path/to/something", post: {
  "some_post_val" => "some_value"
})
```

### Extra headers
```ruby
res = http.post(
  url: "path",
  headers: {"Auth": "123"},
  post: {data: "test"}
)
```

### Post JSON as content
```ruby
res = http.post(url: "path/to/something", json: {some_argument: true})
```

### Reading JSON from request
```ruby
res = http.post(url: "something", json: {some_argument: true})
res.json? #=> true (if content-type is application/json)
res.json #=> {"value" => "something"}
```

## Delete requests
```ruby
res = http.delete(url: "path/to/something")
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

## Building URL's
```ruby
ub = ::Http2::UrlBuilder.new
ub.host = "www.google.com"
ub.port = 80
ub.path = "script.php"
ub.params["some_param"] = 2

ub.build #=> "http://www.google.com/..."
ub.build_params #=> "some_param=2&some_other_param=..."
ub.build_path_and_params #=> "script.php?some_param=2"
ub.params? #=> true
ub.host #=> "www.google.com"
ub.port #=> 80
ub.path #=> "script.php"
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


## Basic HTTP authentication for all requests

```ruby
http = Http2.new(
  host: "www.somehost.com",
  basic_auth: {
    user: "username",
    passwd: "password"
  }
)
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
