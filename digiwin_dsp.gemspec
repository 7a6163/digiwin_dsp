# frozen_string_literal: true

require_relative "lib/digiwin_dsp/version"

Gem::Specification.new do |spec|
  spec.name = "digiwin_dsp"
  spec.version = DigiwinDsp::VERSION
  spec.authors = ["Zac"]
  spec.email = ["579103+7a6163@users.noreply.github.com"]

  spec.summary = "Ruby client for the Digiwin DSP Self-hosted Website Module (自有官網模組) API."
  spec.description = "Synchronous Ruby gem wrapping the Digiwin DSP Self-hosted Website Module " \
                     "(自有官網模組) endpoints — create order, cancel order, invoice update, " \
                     "and return — for use from a Rails storefront."
  spec.homepage = "https://github.com/7a6163/digiwin_dsp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "exe/*",
    "README.md",
    "LICENSE.txt",
    "CHANGELOG.md"
  ].reject { |f| File.directory?(f) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.9"
  spec.add_dependency "faraday-retry", "~> 2.2"
  spec.add_dependency "zeitwerk", "~> 2.6"
end
