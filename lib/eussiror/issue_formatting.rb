# frozen_string_literal: true

module Eussiror
  # Builds GitHub issue bodies and occurrence comments.
  # Accepts either a Rack env hash or a plain Rails.error context hash.
  module IssueFormatting
    USER_ID_KEY    = "eussiror.user_id"
    USER_LABEL_KEY = "eussiror.user_label"

    class << self
      def issue_body(exception, context, fingerprint, config, max_backtrace_lines, source_tag: "error")
        normalized = ContextExtractor.normalize(context)
        <<~BODY
          #{error_details_section(exception)}
          #{context_section(config, source_tag)}
          #{user_section(normalized, config)}
          #{request_section(normalized, config)}
          ## Backtrace

          ```
          #{format_backtrace(exception, max_backtrace_lines)}
          ```

          <!-- #{GithubClient::FINGERPRINT_MARKER}:#{fingerprint} -->
        BODY
      end

      def occurrence_comment(context, config)
        normalized = ContextExtractor.normalize(context)
        occurrence_lines(normalized, config).join("\n\n")
      end

      private

      def format_backtrace(exception, max_lines)
        (exception.backtrace || []).first(max_lines).join("\n")
      end

      def error_details_section(exception)
        ts = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
        <<~SECTION
          ## Error Details

          **Exception:** `#{exception.class}`
          **Message:** #{exception.message}
          **First occurrence:** #{ts}
        SECTION
      end

      def context_section(config, source_tag)
        lines = ["**Environment:** `#{config.environment_name}`"]
        lines << "**Source:** `#{source_tag}`" unless source_tag == "error"
        rel = ReleaseEnv.label
        lines << "**Release:** `#{rel}`" if rel

        <<~SECTION

          ## Context

          #{lines.join("\n")}
        SECTION
      end

      def user_section(normalized, config)
        return "" unless config.issue_privacy == :full

        uid   = normalized[:user_id]
        label = normalized[:user_label]
        return "" if string_blank?(uid) && string_blank?(label)

        parts = []
        parts << "**User id:** `#{uid}`" unless string_blank?(uid)
        parts << "**User label:** #{label}" unless string_blank?(label)

        <<~SECTION

          ## User

          #{parts.join("\n")}
        SECTION
      end

      def request_section(normalized, config)
        fragment = build_request_fragment(normalized, config)
        return "" if string_blank?(fragment)

        <<~SECTION

          ## Request

          #{fragment.strip}
        SECTION
      end

      def build_request_fragment(normalized, config)
        method = normalized[:request_method]
        path   = normalized[:path]
        return "" unless method && path

        lines = ["**Request:** `#{method} #{path}`"]
        return lines.join("\n") if config.issue_privacy == :minimal

        append_ip_and_agent(lines, normalized)
        lines.join("\n")
      end

      def append_ip_and_agent(lines, normalized)
        ra = normalized[:remote_ip]
        lines << "**Remote IP:** #{ra}" unless string_blank?(ra)
        ua = normalized[:user_agent]
        lines << "**User-Agent:** #{ua}" unless string_blank?(ua)
      end

      def occurrence_lines(normalized, config)
        ts = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
        lines = ["**New occurrence:** #{ts}"]
        req = request_summary_line(normalized)
        lines << "**Request:** `#{req}`" if req
        append_occurrence_privacy(lines, normalized, config)
        lines
      end

      def append_occurrence_privacy(lines, normalized, config)
        case config.issue_privacy
        when :standard, :full
          ra = normalized[:remote_ip]
          lines << "**Remote IP:** #{ra}" unless string_blank?(ra)
          ua = normalized[:user_agent]
          lines << "**User-Agent:** #{ua}" unless string_blank?(ua)
        end
        return unless config.issue_privacy == :full

        uid = normalized[:user_id]
        lines << "**User id:** `#{uid}`" unless string_blank?(uid)
      end

      def request_summary_line(normalized)
        method = normalized[:request_method]
        path   = normalized[:path]
        return nil unless method && path

        "#{method} #{path}"
      end

      def string_blank?(value)
        value.nil? || value.to_s.strip.empty?
      end
    end
  end
end
