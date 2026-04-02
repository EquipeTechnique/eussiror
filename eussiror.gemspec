# frozen_string_literal: true

require_relative "lib/eussiror/version"

Gem::Specification.new do |spec|
  spec.name    = "eussiror"
  spec.version = Eussiror::VERSION
  spec.authors = ["Equipe Technique"]
  spec.email   = []

  spec.summary     = "Automatically create GitHub issues from Rails exceptions"
  spec.description = <<~DESC
    Eussiror subscribes to Rails.error and automatically creates GitHub issues
    when unhandled exceptions occur — whether in HTTP requests, ActiveJob,
    Action Cable, or any other Rails execution context.
    If an issue already exists for the same error (identified by fingerprint),
    it adds a comment with the new occurrence instead.
  DESC
  spec.homepage = "https://github.com/EquipeTechnique/eussiror"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

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
