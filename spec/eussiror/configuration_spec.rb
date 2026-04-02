# frozen_string_literal: true

require "spec_helper"

RSpec.describe Eussiror::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "sets environments to production only" do
      expect(config.environments).to eq(%w[production])
    end

    it "sets labels to an empty array" do
      expect(config.labels).to eq([])
    end

    it "sets assignees to an empty array" do
      expect(config.assignees).to eq([])
    end

    it "sets ignored_exceptions to an empty array" do
      expect(config.ignored_exceptions).to eq([])
    end

    it "enables async mode by default" do
      expect(config.async).to be(true)
    end

    it "has no github_token" do
      expect(config.github_token).to be_nil
    end

    it "has no github_repository" do
      expect(config.github_repository).to be_nil
    end

    it "sets issue_privacy to :minimal by default" do
      expect(config.issue_privacy).to eq(:minimal)
    end
  end

  describe "#issue_privacy=" do
    it "accepts string values" do
      config.issue_privacy = "standard"
      expect(config.issue_privacy).to eq(:standard)
    end

    it "raises ArgumentError for unknown values" do
      expect { config.issue_privacy = :invalid }.to raise_error(ArgumentError, /issue_privacy must be one of/)
    end
  end

  describe "#environment_name" do
    let(:rails_with_broken_env) do
      Object.new.tap do |o|
        o.instance_eval do
          def respond_to?(name, _include_all: false)
            name == :env
          end

          def env
            raise NoMethodError, "test"
          end
        end
      end
    end

    it "returns a non-empty string (same source as environment guards)" do
      expect(config.environment_name).to be_a(String)
      expect(config.environment_name.length).to be_positive
    end

    it "falls back to ENV when Rails is defined but #env raises NoMethodError" do
      stub_const("Rails", rails_with_broken_env)
      allow(ENV).to receive(:fetch).and_wrap_original do |original, *args|
        args[0] == "RAILS_ENV" && args[1] == "development" ? "staging" : original.call(*args)
      end

      expect(config.environment_name).to eq("staging")
    end
  end

  describe "#valid?" do
    it "returns false when token is missing" do
      config.github_repository = "owner/repo"
      expect(config.valid?).to be(false)
    end

    it "returns false when repository is missing" do
      config.github_token = "token123"
      expect(config.valid?).to be(false)
    end

    it "returns false when token is blank" do
      config.github_token      = "   "
      config.github_repository = "owner/repo"
      expect(config.valid?).to be(false)
    end

    it "returns true when both token and repository are present" do
      config.github_token      = "token123"
      config.github_repository = "owner/repo"
      expect(config.valid?).to be(true)
    end
  end

  describe "#reporting_enabled?" do
    before do
      config.github_token      = "token123"
      config.github_repository = "owner/repo"
    end

    it "returns false when RAILS_ENV is not in environments" do
      allow(ENV).to receive(:fetch).with("RAILS_ENV", "development").and_return("development")
      config.environments = %w[production]
      expect(config.reporting_enabled?).to be(false)
    end

    it "returns true when RAILS_ENV matches" do
      allow(ENV).to receive(:fetch).with("RAILS_ENV", "development").and_return("production")
      config.environments = %w[production]
      expect(config.reporting_enabled?).to be(true)
    end

    it "returns true for staging when staging is configured" do
      allow(ENV).to receive(:fetch).with("RAILS_ENV", "development").and_return("staging")
      config.environments = %w[production staging]
      expect(config.reporting_enabled?).to be(true)
    end

    it "returns false when config is invalid even if env matches" do
      config.github_token = nil
      allow(ENV).to receive(:fetch).with("RAILS_ENV", "development").and_return("production")
      config.environments = %w[production]
      expect(config.reporting_enabled?).to be(false)
    end
  end

  describe "#valid? with blank repository" do
    it "returns false when repository is blank" do
      config.github_token      = "token123"
      config.github_repository = "   "
      expect(config.valid?).to be(false)
    end
  end

  describe "Eussiror.configure" do
    it "yields the configuration object" do
      Eussiror.configure do |c|
        c.github_token      = "mytoken"
        c.github_repository = "org/repo"
      end

      expect(Eussiror.configuration.github_token).to eq("mytoken")
      expect(Eussiror.configuration.github_repository).to eq("org/repo")
    end
  end
end
