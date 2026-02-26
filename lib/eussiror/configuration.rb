# frozen_string_literal: true

module Eussiror
  class Configuration
    # Required settings
    attr_accessor :github_token, :github_repository

    # Environments where issue reporting is active (default: production only)
    attr_accessor :environments

    # Optional GitHub issue metadata
    attr_accessor :labels, :assignees

    # Exception classes to ignore (array of strings)
    attr_accessor :ignored_exceptions

    # Set to false to report synchronously (useful in tests)
    attr_accessor :async

    def initialize
      @environments       = %w[production]
      @labels             = []
      @assignees          = []
      @ignored_exceptions = []
      @async              = true
    end

    def valid?
      github_token.to_s.strip.length.positive? &&
        github_repository.to_s.strip.length.positive?
    end

    def reporting_enabled?
      valid? && environments.include?(current_environment)
    end

    private

    def current_environment
      return ENV.fetch("RAILS_ENV", "development") unless defined?(Rails)
      return Rails.env.to_s if Rails.respond_to?(:env)

      ENV.fetch("RAILS_ENV", "development")
    rescue NoMethodError
      ENV.fetch("RAILS_ENV", "development")
    end
  end
end
