# frozen_string_literal: true

module Eussiror
  module ErrorReporter
    # Maximum number of backtrace lines included in an issue body.
    MAX_BACKTRACE_LINES = 20

    # Rack env keys for optional user context (same as IssueFormatting::USER_ID_KEY).
    USER_ID_KEY    = IssueFormatting::USER_ID_KEY
    USER_LABEL_KEY = IssueFormatting::USER_LABEL_KEY

    class << self
      # Entry point called by the middleware.
      # Checks configuration guards, then dispatches async or sync.
      def report(exception, env = {})
        config = Eussiror.configuration

        return unless config.reporting_enabled?
        return if ignored?(exception, config)

        if config.async
          Thread.new { process(exception, env, config) }
        else
          process(exception, env, config)
        end
      rescue StandardError => e
        warn "[Eussiror] ErrorReporter.report raised an unexpected error: #{e.class}: #{e.message}"
      end

      private

      def ignored?(exception, config)
        config.ignored_exceptions.any? do |klass_name|
          exception.is_a?(Object.const_get(klass_name))
        rescue NameError
          false
        end
      end

      def process(exception, env, config)
        fingerprint = Fingerprint.compute(exception)
        client = GithubClient.new(
          token: config.github_token,
          repository: config.github_repository
        )

        existing_issue = client.find_issue(fingerprint)

        if existing_issue
          client.add_comment(existing_issue, body: IssueFormatting.occurrence_comment(env, config))
        else
          client.create_issue(
            title: issue_title(exception),
            body: IssueFormatting.issue_body(exception, env, fingerprint, config, MAX_BACKTRACE_LINES),
            labels: config.labels,
            assignees: config.assignees
          )
        end
      rescue StandardError => e
        warn "[Eussiror] Failed to report exception to GitHub: #{e.class}: #{e.message}"
      end

      def issue_title(exception)
        message = exception.message.to_s.lines.first.to_s.strip[0, 120]
        "[500] #{exception.class}: #{message}"
      end
    end
  end
end
