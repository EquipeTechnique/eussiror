# frozen_string_literal: true

require "spec_helper"

RSpec.describe Eussiror::ErrorSubscriber do
  subject(:subscriber) { described_class.new }

  let(:error) { RuntimeError.new("The truth is out there") }

  before do
    allow(Eussiror::ErrorReporter).to receive(:report)
  end

  describe "#report" do
    it "forwards unhandled :error exceptions to ErrorReporter" do
      subscriber.report(error, handled: false, severity: :error, context: {}, source: "application")

      expect(Eussiror::ErrorReporter).to have_received(:report).with(error, {}, source: "application")
    end

    it "skips handled errors by default" do
      subscriber.report(error, handled: true, severity: :error, context: {})

      expect(Eussiror::ErrorReporter).not_to have_received(:report)
    end

    it "forwards handled errors when report_handled_errors is true" do
      Eussiror.configuration.report_handled_errors = true
      subscriber.report(error, handled: true, severity: :error, context: {}, source: "application")

      expect(Eussiror::ErrorReporter).to have_received(:report).with(error, {}, source: "application")
    end

    it "skips :warning severity" do
      subscriber.report(error, handled: false, severity: :warning, context: {})

      expect(Eussiror::ErrorReporter).not_to have_received(:report)
    end

    it "skips :info severity" do
      subscriber.report(error, handled: false, severity: :info, context: {})

      expect(Eussiror::ErrorReporter).not_to have_received(:report)
    end

    it "passes the source through to ErrorReporter" do
      subscriber.report(error, handled: false, severity: :error, context: {}, source: "ActiveJob")

      expect(Eussiror::ErrorReporter).to have_received(:report).with(error, {}, source: "ActiveJob")
    end

    it "passes context through to ErrorReporter" do
      ctx = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/xfiles/cases" }
      subscriber.report(error, handled: false, severity: :error, context: ctx, source: "application")

      expect(Eussiror::ErrorReporter).to have_received(:report).with(error, ctx, source: "application")
    end

    it "forwards nested context payload unchanged" do
      ctx = { env: { REQUEST_METHOD: "GET", PATH_INFO: "/xfiles/archives" } }
      subscriber.report(error, handled: false, severity: :error, context: ctx, source: "ActiveJob::Base")

      expect(Eussiror::ErrorReporter).to have_received(:report).with(
        error, ctx, source: "ActiveJob::Base"
      )
    end
  end
end
