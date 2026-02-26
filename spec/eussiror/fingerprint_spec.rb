# frozen_string_literal: true

require "spec_helper"

RSpec.describe Eussiror::Fingerprint do
  def build_exception(klass: RuntimeError, message: "something went wrong", backtrace: nil)
    exception = klass.new(message)
    exception.set_backtrace(backtrace || ["app/controllers/foo_controller.rb:42:in 'bar'"])
    exception
  end

  describe ".compute" do
    it "returns a 12-character hex string" do
      fp = described_class.compute(build_exception)
      expect(fp).to match(/\A[0-9a-f]{12}\z/)
    end

    it "returns the same fingerprint for identical exceptions" do
      ex1 = build_exception
      ex2 = build_exception
      expect(described_class.compute(ex1)).to eq(described_class.compute(ex2))
    end

    it "returns different fingerprints for different exception classes" do
      ex1 = build_exception(klass: RuntimeError)
      ex2 = build_exception(klass: ArgumentError)
      expect(described_class.compute(ex1)).not_to eq(described_class.compute(ex2))
    end

    it "returns different fingerprints for different messages" do
      ex1 = build_exception(message: "error A")
      ex2 = build_exception(message: "error B")
      expect(described_class.compute(ex1)).not_to eq(described_class.compute(ex2))
    end

    it "returns different fingerprints for different backtrace origins" do
      ex1 = build_exception(backtrace: ["app/controllers/a_controller.rb:1:in 'action'"])
      ex2 = build_exception(backtrace: ["app/controllers/b_controller.rb:2:in 'action'"])
      expect(described_class.compute(ex1)).not_to eq(described_class.compute(ex2))
    end

    it "handles exceptions with no backtrace" do
      exception = RuntimeError.new("no trace")
      exception.set_backtrace(nil)
      expect { described_class.compute(exception) }.not_to raise_error
    end

    it "skips gem lines and uses first app line" do
      gem_line = "/home/user/.rvm/gems/ruby-3.2.0/gems/rack-3.0/lib/rack/base.rb:10"
      app_line = "app/controllers/home_controller.rb:5:in 'index'"

      ex = build_exception(backtrace: [gem_line, app_line])
      fp_app = described_class.compute(ex)

      ex_gem_only = build_exception(backtrace: [gem_line])
      fp_gem = described_class.compute(ex_gem_only)

      expect(fp_app).not_to eq(fp_gem)
    end

    it "truncates long messages to 200 characters when computing" do
      long_message = "x" * 300
      short_message = "x" * 200

      ex_long  = build_exception(message: long_message)
      ex_short = build_exception(message: short_message)

      expect(described_class.compute(ex_long)).to eq(described_class.compute(ex_short))
    end

    it "handles an empty backtrace array without raising" do
      exception = RuntimeError.new("empty trace")
      exception.set_backtrace([])
      expect { described_class.compute(exception) }.not_to raise_error
    end

    context "when filtering gem path patterns" do
      %w[/ruby/ /rubygems vendor/bundle].each do |pattern|
        it "skips lines containing '#{pattern}'" do
          gem_line = "/usr/local/lib#{pattern}foo.rb:1"
          app_line = "app/controllers/clean.rb:5:in 'action'"

          ex = build_exception(backtrace: [gem_line, app_line])
          fp_with_app = described_class.compute(ex)

          ex_pattern_only = build_exception(backtrace: [gem_line])
          fp_pattern_only = described_class.compute(ex_pattern_only)

          expect(fp_with_app).not_to eq(fp_pattern_only)
        end
      end
    end
  end
end
