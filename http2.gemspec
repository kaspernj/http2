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

  s.add_runtime_dependency("string-cases", ">= 0")
  s.add_development_dependency("best_practice_project")
  s.add_development_dependency("bundler", ">= 1.0.0")
  s.add_development_dependency("hayabusa", ">= 0.0.30")
  s.add_development_dependency("json")
  s.add_development_dependency("rake")
  s.add_development_dependency("rdoc")
  s.add_development_dependency("rspec")
  s.add_development_dependency("rubocop")
  s.add_development_dependency("rubocop-performance")
  s.add_development_dependency("rubocop-rake")
  s.add_development_dependency("rubocop-rspec")
  s.add_development_dependency("sqlite3")
  s.add_development_dependency "wref", ">= 0.0.8"
end
