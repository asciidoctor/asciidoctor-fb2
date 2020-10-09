# frozen_string_literal: true

require_relative 'lib/asciidoctor_fb2/version'

Gem::Specification.new do |s|
  s.name = 'asciidoctor-fb2'
  s.version = Asciidoctor::FB2::VERSION
  s.authors = ['Marat Radchenko']
  s.email = ['marat@slonopotamus.org']
  s.summary = 'Converts AsciiDoc documents to FB2 e-book formats'
  s.homepage = 'https://github.com/slonopotamus/asciidoctor-fb2'
  s.license = 'MIT'
  s.required_ruby_version = '>= 2.4.0'

  s.files = `git ls-files`.split("\n").reject { |f| f.match(%r{^spec/}) }
  s.executables = `git ls-files -- bin/*`.split("\n").map do |f|
    File.basename(f)
  end
  s.require_paths = ['lib']

  s.add_runtime_dependency 'asciidoctor', '~> 2.0'
  s.add_runtime_dependency 'fb2rb', '~> 0.3.0'

  s.add_development_dependency 'asciidoctor-diagram', '~> 2.0'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.9.0'
  s.add_development_dependency 'rubocop', '~> 0.93.0'
  s.add_development_dependency 'rubocop-rspec', '~> 1.43.1'
end
