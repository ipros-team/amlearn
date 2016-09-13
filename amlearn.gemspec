# -*- encoding: utf-8 -*-

require File.expand_path('../lib/amlearn/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "amlearn"
  gem.version       = Amlearn::VERSION
  gem.summary       = %q{Amazon Machine Learning opeartion very simply.}
  gem.description   = %q{Amazon Machine Learning opeartion very simply.}
  gem.license       = "MIT"
  gem.authors       = ["toyama0919"]
  gem.email         = "toyama0919@gmail.com"
  gem.homepage      = "https://github.com/toyama0919/amlearn"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'thor', '~> 0.19.1'

  gem.add_development_dependency 'bundler', '~> 1.7.2'
  gem.add_development_dependency 'pry', '~> 0.10.1'
  gem.add_development_dependency 'rake', '~> 10.3.2'
  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'rubocop', '~> 0.24.1'
  gem.add_development_dependency 'rubygems-tasks', '~> 0.2'
  gem.add_development_dependency 'yard', '~> 0.8'
end
