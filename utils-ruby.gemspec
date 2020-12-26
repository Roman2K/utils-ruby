Gem::Specification.new do |s|
  s.name    = File.basename(__FILE__, ".gemspec")
  s.version = '0.1.0'
  s.summary = s.name
  s.authors = ["Roman Le Négrate"]
  s.require_paths = ["."]
  s.files   = Dir["**.rb"]

  s.add_runtime_dependency 'net_http_unix', '~> 0.2'
end
