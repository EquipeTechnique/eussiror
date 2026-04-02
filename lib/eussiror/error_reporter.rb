# frozen_string_literal: true

module Eussiror
  module ErrorReporter
    MAX_BACKTRACE_LINES = 20

    USER_ID_KEY    = IssueFormatting::USER_ID_KEY
    USER_LABEL_KEY = IssueFormatting::USER_LABEL_KEY

    # Maps Rails.error source strings to short tags for issue titles.
    SOURCE_TAGS = {
      "application" => "error",
      "ActionDispatch::Executor" => "request",
      "ActiveJob" => "job",
      "ActionCable::Connection" => "cable"
    }.freeze

    class << self
      def report(exception, context = {}, source: "application")
        config = Eussiror.configuration

        return unless config.reporting_enabled?
        return if ignored?(exception, config)

        tag = source_tag_for(source)
        if config.async
          Thread.new { process(exception, context, config, tag) }
        else
          process(exception, context, config, tag)
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

      def source_tag_for(source)
        src = source.to_s
        return SOURCE_TAGS[src] if SOURCE_TAGS.key?(src)

        down = src.downcase
        return "job" if down.include?("activejob")
        return "cable" if down.include?("actioncable")
        return "request" if down.include?("actiondispatch") || down.include?("rack")

        "error"
      end

      def process(exception, context, config, tag)
        fingerprint = Fingerprint.compute(exception)
        client = GithubClient.new(
          token: config.github_token,
          repository: config.github_repository
        )

        existing_issue = client.find_issue(fingerprint)

        if existing_issue
          client.add_comment(existing_issue, body: IssueFormatting.occurrence_comment(context, config))
        else
          client.create_issue(
            title: issue_title(exception, tag),
            body: IssueFormatting.issue_body(
              exception, context, fingerprint, config, MAX_BACKTRACE_LINES, source_tag: tag
            ),
            labels: config.labels,
            assignees: config.assignees
          )
        end
      rescue StandardError => e
        warn "[Eussiror] Failed to report exception to GitHub: #{e.class}: #{e.message}"
      end

      def issue_title(exception, tag)
        message = exception.message.to_s.lines.first.to_s.strip[0, 120]
        "[#{tag}] #{exception.class}: #{message}"
      end
    end
  end
end
