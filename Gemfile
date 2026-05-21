# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", "~> 13.0"

group :development, :test do
  gem "bundler-audit", "~> 0.9", require: false
  gem "irb"
  # parallel 2.x dropped Ruby 3.2 support; pinning keeps rubocop installable
  # on the CI 3.2 row while the gem itself stays compatible with Ruby >= 3.2.
  gem "parallel", "< 2.0"
  gem "pry"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.65"
  gem "rubocop-rspec", "~> 3.0"
  gem "simplecov", "~> 0.22", require: false
  gem "simplecov-lcov", "~> 0.8", require: false
  gem "vcr", "~> 6.3"
  gem "webmock", "~> 3.23"
end
