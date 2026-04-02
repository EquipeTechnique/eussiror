# frozen_string_literal: true

module Eussiror
  # Builds GitHub issue bodies and occurrence comments from exceptions and Rack env.
  # Respects Configuration#issue_privacy.
  module IssueFormatting
    USER_ID_KEY    = "eussiror.user_id"
    USER_LABEL_KEY = "eussiror.user_label"

    class << self
      def issue_body(exception, env, fingerprint, config, max_backtrace_lines)
        <<~BODY
          #{error_details_section(exception)}
          #{context_section(config)}
          #{user_section(env, config)}
          #{request_section(env, config)}
          ## Backtrace

          ```
          #{format_backtrace(exception, max_backtrace_lines)}
          ```

          <!-- #{GithubClient::FINGERPRINT_MARKER}:#{fingerprint} -->
        BODY
      end

      def occurrence_comment(env, config)
        occurrence_lines(env, config).join("\n\n")
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

      def context_section(config)
        lines = ["**Environment:** `#{config.environment_name}`"]
        rel = ReleaseEnv.label
        lines << "**Release:** `#{rel}`" if rel

        <<~SECTION

          ## Context

          #{lines.join("\n")}
        SECTION
      end

      def user_section(env, config)
        return "" unless config.issue_privacy == :full

        uid   = env[USER_ID_KEY]
        label = env[USER_LABEL_KEY]
        return "" if string_blank?(uid) && string_blank?(label)

        parts = []
        parts << "**User id:** `#{uid}`" unless string_blank?(uid)
        parts << "**User label:** #{label}" unless string_blank?(label)

        <<~SECTION

          ## User

          #{parts.join("\n")}
        SECTION
      end

      def request_section(env, config)
        fragment = build_request_fragment(env, config)
        return "" if string_blank?(fragment)

        <<~SECTION

          ## Request

          #{fragment.strip}
        SECTION
      end

      def build_request_fragment(env, config)
        return "" if env.blank?

        method = env["REQUEST_METHOD"]
        path   = env["PATH_INFO"]
        return "" unless method && path

        lines = ["**Request:** `#{method} #{path}`"]
        return lines.join("\n") if config.issue_privacy == :minimal

        append_ip_and_agent(lines, env)
        lines.join("\n")
      end

      def append_ip_and_agent(lines, env)
        ra = env["REMOTE_ADDR"]
        lines << "**Remote IP:** #{ra}" unless string_blank?(ra)
        ua = env["HTTP_USER_AGENT"]
        lines << "**User-Agent:** #{ua}" unless string_blank?(ua)
      end

      def occurrence_lines(env, config)
        ts = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
        lines = ["**New occurrence:** #{ts}"]
        req = request_summary_line(env)
        lines << "**Request:** `#{req}`" if req
        append_occurrence_privacy(lines, env, config)
        lines
      end

      def append_occurrence_privacy(lines, env, config)
        case config.issue_privacy
        when :standard, :full
          ra = env["REMOTE_ADDR"]
          lines << "**Remote IP:** #{ra}" unless string_blank?(ra)
          ua = env["HTTP_USER_AGENT"]
          lines << "**User-Agent:** #{ua}" unless string_blank?(ua)
        end
        return unless config.issue_privacy == :full

        uid = env[USER_ID_KEY]
        lines << "**User id:** `#{uid}`" unless string_blank?(uid)
      end

      def request_summary_line(env)
        return nil if env.blank?

        method = env["REQUEST_METHOD"]
        path   = env["PATH_INFO"]
        return nil unless method && path

        "#{method} #{path}"
      end

      def string_blank?(value)
        value.nil? || value.to_s.strip.empty?
      end
    end
  end
end
