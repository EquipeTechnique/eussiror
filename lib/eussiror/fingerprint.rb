# frozen_string_literal: true

require "digest"

module Eussiror
  module Fingerprint
    # Number of hex characters kept from the SHA256 digest.
    DIGEST_LENGTH = 12

    # Lines from these path fragments are excluded when looking for the
    # "first application line" in a backtrace.
    GEM_PATH_PATTERNS = %w[/gems/ /ruby/ /rubygems vendor/bundle].freeze

    # Computes a stable, short fingerprint for a given exception.
    #
    # The fingerprint is based on:
    #   - The exception class name
    #   - The first 200 characters of the message
    #   - The first backtrace line that belongs to the application (not a gem)
    #
    # Returns a 12-character lowercase hex string.
    def self.compute(exception)
      parts = [
        exception.class.name,
        exception.message.to_s[0, 200],
        first_app_backtrace_line(exception)
      ]

      Digest::SHA256.hexdigest(parts.join("|"))[0, DIGEST_LENGTH]
    end

    def self.first_app_backtrace_line(exception)
      backtrace = exception.backtrace || []
      backtrace.find { |line| GEM_PATH_PATTERNS.none? { |pattern| line.include?(pattern) } } || backtrace.first.to_s
    end
    private_class_method :first_app_backtrace_line
  end
end
