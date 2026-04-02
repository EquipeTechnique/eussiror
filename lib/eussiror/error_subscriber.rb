# frozen_string_literal: true

module Eussiror
  # Rails.error subscriber (ActiveSupport::ErrorReporter).
  # Registered via Railtie so that Eussiror receives every unhandled exception
  # regardless of origin (HTTP request, ActiveJob, Action Cable, Rake, etc.).
  class ErrorSubscriber
    def report(error, handled:, severity:, context:, source: "application")
      return if handled && !Eussiror.configuration.report_handled_errors
      return unless severity == :error

      ErrorReporter.report(error, context, source: source)
    end
  end
end
