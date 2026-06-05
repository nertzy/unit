require_relative 'lib/unit/version'

Gem::Specification.new do |s|
  s.name = 'unit'
  s.version = Unit::VERSION
  s.summary = 'Scientific unit support for ruby for calculations'
  s.description = 'Unit introduces computational units to Ruby, with built-in ' \
    'support for binary, mathematical, SI, imperial, scientific and temporal ' \
    'units, unit-aware arithmetic and conversions, and a simple interface for ' \
    'defining your own custom units.'
  s.homepage = 'https://github.com/minad/unit'
  s.license = 'MIT'

  s.authors = ['Daniel Mendler', 'Chris Cashwell']
  s.email = ['mail@daniel-mendler.de']

  s.required_ruby_version = '>= 3.3'

  s.metadata = {
    'source_code_uri'       => s.homepage,
    'bug_tracker_uri'       => "#{s.homepage}/issues",
    'rubygems_mfa_required' => 'true',
  }

  s.files         = Dir['lib/**/*.{rb,yml}'] + %w[README.markdown LICENSE]
  s.require_paths = ['lib']

  s.add_development_dependency('rake', ['~> 13.0'])
  s.add_development_dependency('rspec', ['~> 3.0'])
end
