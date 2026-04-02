# frozen_string_literal: true

module Eussiror
  # First non-empty value wins. `RELEASE` is the explicit override; others are common PaaS/CI conventions.
  module ReleaseEnv
    KEYS = %w[
      RELEASE
      SOURCE_VERSION
      HEROKU_SLUG_COMMIT
      RAILWAY_GIT_COMMIT_SHA
      RENDER_GIT_COMMIT
      REVISION
      GIT_COMMIT
      CI_COMMIT_SHA
      GITHUB_SHA
    ].freeze

    def self.label
      KEYS.lazy.map { |k| ENV.fetch(k, nil) }.find { |v| v.to_s.strip.length.positive? }
    end
  end
end
