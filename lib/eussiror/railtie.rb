# frozen_string_literal: true

require "rails/railtie"

module Eussiror
  class Railtie < Rails::Railtie
    # Insert before ShowExceptions so we wrap the full Rails error rendering.
    # On the way back out, we inspect the rendered response and env to detect 500s.
    initializer "eussiror.insert_middleware" do |app|
      app.middleware.insert_before ActionDispatch::ShowExceptions, Eussiror::Middleware
    end
  end
end
