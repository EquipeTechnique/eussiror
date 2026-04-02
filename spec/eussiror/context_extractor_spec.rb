# frozen_string_literal: true

require "spec_helper"

RSpec.describe Eussiror::ContextExtractor do
  def expect_normalized(context, expected)
    expect(described_class.normalize(context)).to include(expected)
  end

  let(:flat_context) do
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/xfiles/health-check",
      "REMOTE_ADDR" => "10.0.0.1",
      "HTTP_USER_AGENT" => "MulderProbe/1.0",
      "eussiror.user_id" => "7",
      "eussiror.user_label" => "dana.scully@fbi.example"
    }
  end

  let(:nested_env_context) do
    {
      env: {
        REQUEST_METHOD: "POST",
        PATH_INFO: "/xfiles/import",
        REMOTE_ADDR: "127.0.0.1",
        HTTP_USER_AGENT: "LoneGunmanBot/9",
        "eussiror.user_id": "99"
      }
    }
  end

  let(:request_double) do
    double(
      request_method: "PATCH",
      fullpath: "/xfiles/casefiles/1",
      path: "/xfiles/casefiles/1",
      remote_ip: "1.1.1.1",
      user_agent: "ScullyRequestAgent",
      ip: "1.1.1.1"
    )
  end

  describe ".normalize" do
    it "extracts from flat string rack keys" do
      expected = { request_method: "GET", path: "/xfiles/health-check", remote_ip: "10.0.0.1" }
      expect_normalized(flat_context, expected)
      expect_normalized(
        flat_context,
        user_agent: "MulderProbe/1.0",
        user_id: "7",
        user_label: "dana.scully@fbi.example"
      )
    end

    it "extracts from symbol keys and nested env" do
      expected = { request_method: "POST", path: "/xfiles/import", remote_ip: "127.0.0.1" }
      expect_normalized(nested_env_context, expected)
      expect_normalized(nested_env_context, user_agent: "LoneGunmanBot/9", user_id: "99")
    end

    it "prefers explicit top-level values over nested ones" do
      ctx = {
        "PATH_INFO" => "/top",
        env: { "PATH_INFO" => "/xfiles/nested" }
      }

      expect(described_class.normalize(ctx)[:path]).to eq("/top")
    end

    it "extracts user-agent from nested headers" do
      ctx = { headers: { "User-Agent" => "curl/8.0" } }

      expect(described_class.normalize(ctx)[:user_agent]).to eq("curl/8.0")
    end

    it "falls back to request object methods" do
      norm = described_class.normalize(request: request_double)
      expect(norm).to include(request_method: "PATCH", path: "/xfiles/casefiles/1")
      expect(norm).to include(remote_ip: "1.1.1.1", user_agent: "ScullyRequestAgent")
    end

    it "returns nil values when no context is available" do
      expect(described_class.normalize(nil)).to include(
        request_method: nil,
        path: nil,
        remote_ip: nil,
        user_agent: nil,
        user_id: nil,
        user_label: nil
      )
    end

    it "handles NoMethodError from request object gracefully" do
      req = Object.new
      def req.respond_to?(name, _include_all: false)
        name == :request_method
      end

      def req.request_method
        raise NoMethodError, "spooky method failure"
      end

      expect(described_class.normalize(request: req)[:request_method]).to be_nil
    end
  end
end
