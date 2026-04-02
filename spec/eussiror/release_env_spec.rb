# frozen_string_literal: true

require "spec_helper"

RSpec.describe Eussiror::ReleaseEnv do
  describe ".label" do
    it "prefers RELEASE over SOURCE_VERSION" do
      apply_env_overrides("RELEASE" => "from-release", "SOURCE_VERSION" => "from-source") do
        expect(described_class.label).to eq("from-release")
      end
    end

    it "uses SOURCE_VERSION when RELEASE is unset" do
      apply_env_overrides("RELEASE" => nil, "SOURCE_VERSION" => "scalingo-sha") do
        expect(described_class.label).to eq("scalingo-sha")
      end
    end
  end
end
