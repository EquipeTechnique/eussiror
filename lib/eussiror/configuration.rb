# frozen_string_literal: true

module Eussiror
  class Configuration
    # Allowed values for #issue_privacy: :minimal (default), :standard, :full
    ISSUE_PRIVACY_LEVELS = %i[minimal standard full].freeze

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

    # Controls how much request/user context is included in GitHub issue bodies and
    # occurrence comments. :minimal is safest for public repos; :full for trusted private teams.
    attr_reader :issue_privacy

    def initialize
      @environments       = %w[production]
      @labels             = []
      @assignees          = []
      @ignored_exceptions = []
      @async              = true
      @issue_privacy      = :minimal
    end

    def issue_privacy=(value)
      @issue_privacy = normalize_issue_privacy(value)
    end

    def valid?
      github_token.to_s.strip.length.positive? &&
        github_repository.to_s.strip.length.positive?
    end

    def reporting_enabled?
      valid? && environments.include?(current_environment)
    end

    # Current Rails / Rack environment name (for display in issue bodies).
    #
    # @return [String]
    def environment_name
      current_environment
    end

    private

    def normalize_issue_privacy(value)
      return :minimal if value.nil?

      sym = value.respond_to?(:to_sym) ? value.to_sym : value.to_s.to_sym
      return sym if ISSUE_PRIVACY_LEVELS.include?(sym)

      raise ArgumentError,
            "issue_privacy must be one of #{ISSUE_PRIVACY_LEVELS.join(', ')}, got #{value.inspect}"
    end

    def current_environment
      return ENV.fetch("RAILS_ENV", "development") unless defined?(Rails)
      return Rails.env.to_s if Rails.respond_to?(:env)

      ENV.fetch("RAILS_ENV", "development")
    rescue NoMethodError
      ENV.fetch("RAILS_ENV", "development")
    end
  end
end
