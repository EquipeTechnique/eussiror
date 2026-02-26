# frozen_string_literal: true

require "spec_helper"

RSpec.describe Eussiror::Middleware do
  let(:app)        { ->(_env) { [status, {}, ["body"]] } }
  let(:middleware) { described_class.new(app) }
  let(:env)        { { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/" } }
  let(:status)     { 200 }

  before do
    allow(Eussiror::ErrorReporter).to receive(:report)
  end

  describe "#call" do
    context "with a 200 response" do
      let(:status) { 200 }

      it "passes through transparently" do
        result_status, = middleware.call(env)
        expect(result_status).to eq(200)
      end

      it "does not call ErrorReporter" do
        middleware.call(env)
        expect(Eussiror::ErrorReporter).not_to have_received(:report)
      end
    end

    context "with a 404 response" do
      let(:status) { 404 }

      it "does not call ErrorReporter" do
        middleware.call(env)
        expect(Eussiror::ErrorReporter).not_to have_received(:report)
      end
    end

    context "with a 500 response and action_dispatch.exception" do
      let(:status)    { 500 }
      let(:exception) { RuntimeError.new("server error") }
      let(:app) do
        ->(_rack_env) { [500, { "Content-Type" => "text/html" }, ["Internal Server Error"]] }
      end

      before do
        env["action_dispatch.exception"] = exception
      end

      it "calls ErrorReporter with the exception" do
        middleware.call(env)
        expect(Eussiror::ErrorReporter).to have_received(:report).with(exception, env)
      end

      it "still returns the 500 status unchanged" do
        result_status, = middleware.call(env)
        expect(result_status).to eq(500)
      end

      it "preserves the response headers unchanged" do
        _, result_headers, = middleware.call(env)
        expect(result_headers).to eq({ "Content-Type" => "text/html" })
      end

      it "preserves the response body unchanged" do
        _, _, result_body = middleware.call(env)
        expect(result_body).to eq(["Internal Server Error"])
      end
    end

    context "with a 500 response but no action_dispatch.exception" do
      let(:status) { 500 }

      it "does not call ErrorReporter" do
        middleware.call(env)
        expect(Eussiror::ErrorReporter).not_to have_received(:report)
      end
    end

    context "when the inner app raises an exception" do
      let(:app) do
        ->(_env) { raise "unexpected crash" }
      end

      it "re-raises the exception" do
        expect { middleware.call(env) }.to raise_error(RuntimeError, "unexpected crash")
      end

      it "calls ErrorReporter before re-raising" do
        begin
          middleware.call(env)
        rescue RuntimeError
          nil
        end

        expect(Eussiror::ErrorReporter).to have_received(:report)
          .with(an_instance_of(RuntimeError), env)
      end
    end
  end
end
