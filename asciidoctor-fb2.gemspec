# frozen_string_literal: true

require_relative 'lib/asciidoctor_fb2/version'

Gem::Specification.new do |s|
  s.name = 'asciidoctor-fb2'
  s.version = Asciidoctor::FB2::VERSION
  s.authors = ['Marat Radchenko']
  s.email = ['marat@slonopotamus.org']
  s.summary = 'Converts AsciiDoc documents to FB2 e-book formats'
  s.homepage = 'https://github.com/asciidoctor/asciidoctor-fb2'
  s.license = 'MIT'
  s.required_ruby_version = '>= 2.7.0'

  s.files = `git ls-files`.split("\n").reject { |f| f.match(%r{^spec/}) }
  s.executables = `git ls-files -- bin/*`.split("\n").map do |f|
    File.basename(f)
  end
  s.require_paths = ['lib']

  s.add_dependency 'asciidoctor', '~> 2.0'
  s.add_dependency 'fb2rb', '~> 0.9.1'
  s.add_dependency 'mime-types', '~> 3.0'

  s.add_development_dependency 'asciidoctor-diagram', '~> 2.0'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.13.0'
  s.add_development_dependency 'rubocop', '~> 1.72.1'
  s.add_development_dependency 'rubocop-rake', '~> 0.6.0'
  s.add_development_dependency 'rubocop-rspec', '~> 3.3'
end
