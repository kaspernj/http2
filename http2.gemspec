Gem::Specification.new do |s|
  s.name = "http2"
  s.version = "0.0.36"

  s.require_paths = ["lib"]
  s.authors = ["Kasper Johansen"]
  s.description = "A lightweight framework for doing http-connections in Ruby. Supports cookies, keep-alive, compressing and much more."
  s.email = "k@spernj.org"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = Dir["{include,lib}/**/*"] + ["Rakefile"]
  s.homepage = "http://github.com/kaspernj/http2"
  s.licenses = ["MIT"]
  s.summary = "A lightweight framework for doing http-connections in Ruby. Supports cookies, keep-alive, compressing and much more."
  s.metadata["rubygems_mfa_required"] = "true"
  s.required_ruby_version = ">= 2.7"

  s.add_dependency("string-cases", ">= 0")
end
