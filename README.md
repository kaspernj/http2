# http2

[![Build Status](https://api.shippable.com/projects/53bd3eef2e23bdcb03c0df9e/badge/master)](https://www.shippable.com/projects/53bd3eef2e23bdcb03c0df9e)
[![Code Climate](https://codeclimate.com/github/kaspernj/http2.png)](https://codeclimate.com/github/kaspernj/http2)

Example of usage:

```ruby
require "rubygems"
require "http2"

Http2.new(:host => "www.google.dk") do |http|
  #Get-request.
  res = http.get("path/to/something")
  puts res.body
  puts "All response-headers: #{res.headers}"
  puts "Specific header: #{res.header("HeaderName")}"
  
  #Post-request.
  res = http.post(:url => "path/to/something", :post => {
    "some_post_val" => "some_value"
  })
  
  #Post-multipart (upload).
  res = http.post_multipart(:url => "path/to/something", :post => {
    "test_file1" => {
      :fpath => fpath,
      :filename => "specfile"
    }
  })
  
  puts "Cookies until now: #{http.cookies}"
end
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

