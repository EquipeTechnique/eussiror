# frozen_string_literal: true

require "rails/railtie"

module Eussiror
  class Railtie < Rails::Railtie
    initializer "eussiror.subscribe_error_reporter" do
      Rails.error.subscribe(Eussiror::ErrorSubscriber.new)
    end
  end
end
