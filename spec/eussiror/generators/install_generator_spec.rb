# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require "rails/generators/testing/behavior"
require "fileutils"
require "generators/eussiror/install/install_generator"

RSpec.describe Eussiror::Generators::InstallGenerator do
  include Rails::Generators::Testing::Behavior
  include FileUtils

  tests described_class
  destination File.expand_path("../../../tmp/generator_test", __dir__)

  before { prepare_destination }

  describe "create_initializer_file" do
    before { generator([], {}).invoke_all }

    let(:initializer_path) { File.join(destination_root, "config/initializers/eussiror.rb") }

    it "creates the initializer file" do
      expect(File).to exist(initializer_path)
    end

    it "includes Eussiror.configure block" do
      content = File.read(initializer_path)
      expect(content).to include("Eussiror.configure do |config|")
    end

    it "includes github_token configuration" do
      content = File.read(initializer_path)
      expect(content).to include("config.github_token")
    end

    it "includes github_repository configuration" do
      content = File.read(initializer_path)
      expect(content).to include("config.github_repository")
    end

    it "includes environments configuration" do
      content = File.read(initializer_path)
      expect(content).to include("config.environments")
    end
  end
end
