# frozen_string_literal: true

module Eussiror
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if status == 500
        exception = env["action_dispatch.exception"]
        ErrorReporter.report(exception, env) if exception
      end

      [status, headers, body]
    rescue Exception => e # rubocop:disable Lint/RescueException
      # The Rails stack re-raises after ShowExceptions in non-standard setups.
      # We still want to capture the exception before propagating it.
      ErrorReporter.report(e, env)
      raise
    end
  end
end
