# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rails_string_enum/version'

Gem::Specification.new do |spec|
  spec.name          = "rails_string_enum"
  spec.version       = RailsStringEnum::VERSION
  spec.authors       = ["ermolaev"]
  spec.email         = ["andrey@ermolaev.me"]

  spec.summary       = %q{support in rails db enums or string (using as flexible enum)}
  spec.description   = %q{migration methods for postgresql enum, internationalization, simple_form}
  spec.homepage      = 'https://github.com/ermolaev/rails_string_enum'
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"

  spec.required_ruby_version = '~> 2.0'
end
