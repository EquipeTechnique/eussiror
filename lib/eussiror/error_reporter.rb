# frozen_string_literal: true

module Eussiror
  module ErrorReporter
    # Maximum number of backtrace lines included in an issue body.
    MAX_BACKTRACE_LINES = 20

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
        client      = GithubClient.new(
          token:      config.github_token,
          repository: config.github_repository
        )

        existing_issue = client.find_issue(fingerprint)

        if existing_issue
          client.add_comment(existing_issue, body: occurrence_comment)
        else
          client.create_issue(
            title:     issue_title(exception),
            body:      issue_body(exception, env, fingerprint),
            labels:    config.labels,
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

      def issue_body(exception, env, fingerprint)
        request_info = build_request_info(env)
        backtrace    = format_backtrace(exception)

        <<~BODY
          ## Error Details

          **Exception:** `#{exception.class}`
          **Message:** #{exception.message}
          **First occurrence:** #{current_timestamp}
          #{request_info}

          ## Backtrace

          ```
          #{backtrace}
          ```

          <!-- #{GithubClient::FINGERPRINT_MARKER}:#{fingerprint} -->
        BODY
      end

      def occurrence_comment
        "**New occurrence:** #{current_timestamp}"
      end

      def current_timestamp
        Time.now.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
      end

      def build_request_info(env)
        return "" if env.nil? || env.empty?

        method      = env["REQUEST_METHOD"]
        path        = env["PATH_INFO"]
        remote_addr = env["REMOTE_ADDR"]

        return "" unless method && path

        parts = ["**Request:** `#{method} #{path}`"]
        parts << "**Remote IP:** #{remote_addr}" if remote_addr

        "\n#{parts.join("\n")}"
      end

      def format_backtrace(exception)
        (exception.backtrace || [])
          .first(MAX_BACKTRACE_LINES)
          .join("\n")
      end
    end
  end
end
