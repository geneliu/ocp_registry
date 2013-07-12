# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ocp_registry/version'

Gem::Specification.new do |spec|
  spec.name          = "ocp_registry"
  spec.version       = OcpRegistry::VERSION
  spec.authors       = ["Wei Tie"]
  spec.email         = ["nuaafe@gmail.com"]
  spec.description   = %q{openstack self-registration app}
  spec.summary       = %q{openstack self-registration app}
  spec.homepage      = ""
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "bundler", "~> 1.3"
  spec.add_dependency "fog", "~>1.12.0"
  spec.add_dependency "mysql2", "~>0.3.0"
  spec.add_dependency "sqlite3", "~>1.3.7"
  spec.add_dependency "sequel", "~>4.0.0"
  spec.add_dependency "sinatra", "~>1.4.3"
  spec.add_dependency "thin", "~>1.5.1"
  spec.add_dependency "tlsmail", "=0.0.1"
  spec.add_dependency "yajl-ruby", "~>1.1.0"

  spec.add_development_dependency "rspec", "~>2.13.0"

end
