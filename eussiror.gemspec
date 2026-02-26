# frozen_string_literal: true

require_relative "lib/eussiror/version"

Gem::Specification.new do |spec|
  spec.name    = "eussiror"
  spec.version = Eussiror::VERSION
  spec.authors = ["Equipe Technique"]
  spec.email   = []

  spec.summary     = "Automatically create GitHub issues from Rails 500 errors"
  spec.description = <<~DESC
    Eussiror hooks into your Rails app and automatically creates GitHub issues
    when unhandled exceptions produce 500 responses in configured environments.
    If an issue already exists for the same error (identified by fingerprint),
    it adds a comment with the new occurrence timestamp instead.
  DESC
  spec.homepage = "https://github.com/tracyloisel/eussiror"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*",
    "LICENSE",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.2"
end
