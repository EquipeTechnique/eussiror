# frozen_string_literal: true

require "eussiror/version"
require "eussiror/configuration"
require "eussiror/fingerprint"
require "eussiror/github_client"
require "eussiror/error_reporter"
require "eussiror/middleware"
require "eussiror/railtie" if defined?(Rails::Railtie)

module Eussiror
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
