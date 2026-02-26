# frozen_string_literal: true

source "https://rubygems.org"

# Resolve stringio version ambiguity (WARN: Unresolved or ambiguous specs)
gem "stringio", ">= 3.0.1.2"

gemspec

group :development, :test do
  gem "appraisal"
  gem "rake"
  gem "rspec-rails"
  gem "rubocop"
  gem "rubocop-rails"
  gem "rubocop-rspec"
  gem "simplecov", require: false
  gem "webmock"
end
