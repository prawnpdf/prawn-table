basedir = File.expand_path(File.dirname(__FILE__))
require "#{basedir}/lib/prawn/table/version"

Gem::Specification.new do |spec|
  spec.name = "prawn-table"
  spec.version = Prawn::Table::VERSION
  spec.platform = Gem::Platform::RUBY
  spec.summary = "Provides tables for PrawnPDF"
  spec.files =  Dir.glob("{examples,lib,spec,manual}/**/**/*") +
                ["prawn-table.gemspec", "Gemfile",
                 "COPYING", "LICENSE", "GPLv2", "GPLv3"]
  spec.require_path = "lib"
  spec.required_ruby_version = '>= 2.6'
  spec.required_rubygems_version = ">= 2.0.0"

  spec.test_files = Dir[ "spec/*_spec.rb" ]
  spec.authors = ["Gregory Brown","Brad Ediger","Daniel Nelson","Jonathan Greenberg","James Healy", "Hartwig Brandl"]
  spec.email = ["gregory.t.brown@gmail.com","brad@bradediger.com","dnelson@bluejade.com","greenberg@entryway.net","jimmy@deefa.com", "mail@hartwigbrandl.at"]
  spec.licenses = %w(PRAWN GPL-2.0 GPL-3.0)

  spec.add_dependency('prawn', '>= 1.3.0', '< 3.0.0')

  spec.add_development_dependency('pdf-inspector', '~> 1.1.0')
  spec.add_development_dependency('yard')
  spec.add_development_dependency('rspec', '~> 3.0')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('simplecov')
  spec.add_development_dependency('prawn-dev', '~> 0.3.0')
  spec.add_development_dependency('prawn-manual_builder', ">= 0.2.0")
  spec.add_development_dependency('pdf-reader', '~>1.2')
  spec.add_development_dependency('matrix')

  spec.homepage = "https://github.com/prawnpdf/prawn-table"
  spec.description = <<END_DESC
  Prawn::Table provides tables for the Prawn PDF toolkit
END_DESC
end
