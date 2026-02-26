# frozen_string_literal: true

require "spec_helper"

RSpec.describe Eussiror::ErrorReporter do
  let(:exception) do
    ex = RuntimeError.new("something went wrong")
    ex.set_backtrace(["app/controllers/home_controller.rb:10:in 'index'"])
    ex
  end

  let(:env) do
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/dashboard",
      "REMOTE_ADDR" => "1.2.3.4"
    }
  end

  def configure_eussiror(env_name: "production", async: false)
    Eussiror.configure do |config|
      config.github_token      = "fake_token"
      config.github_repository = "owner/repo"
      config.environments      = [env_name]
      config.async             = async
    end
    allow(ENV).to receive(:fetch).with("RAILS_ENV", "development").and_return(env_name)
  end

  describe ".report" do
    context "when reporting is not enabled" do
      it "does nothing when configuration is invalid (no token)" do
        Eussiror.configure do |c|
          c.github_repository = "owner/repo"
          c.environments      = %w[production]
        end
        allow(ENV).to receive(:fetch).with("RAILS_ENV", "development").and_return("production")
        allow(Eussiror::GithubClient).to receive(:new)

        described_class.report(exception, env)

        expect(Eussiror::GithubClient).not_to have_received(:new)
      end

      it "does nothing when current env is not in configured environments" do
        configure_eussiror(env_name: "production")
        allow(ENV).to receive(:fetch).with("RAILS_ENV", "development").and_return("development")
        allow(Eussiror::GithubClient).to receive(:new)

        described_class.report(exception, env)

        expect(Eussiror::GithubClient).not_to have_received(:new)
      end
    end

    context "when the exception class is ignored" do
      it "skips reporting" do
        configure_eussiror
        Eussiror.configuration.ignored_exceptions = %w[RuntimeError]
        allow(Eussiror::GithubClient).to receive(:new)

        described_class.report(exception, env)

        expect(Eussiror::GithubClient).not_to have_received(:new)
      end

      it "skips reporting for subclass of ignored exception" do
        configure_eussiror
        Eussiror.configuration.ignored_exceptions = %w[StandardError]
        allow(Eussiror::GithubClient).to receive(:new)

        described_class.report(exception, env)

        expect(Eussiror::GithubClient).not_to have_received(:new)
      end

      it "does not skip reporting when the class name does not exist (NameError rescued)" do
        configure_eussiror
        Eussiror.configuration.ignored_exceptions = %w[NonExistent::ClassName]

        mock_client = instance_double(Eussiror::GithubClient)
        allow(Eussiror::GithubClient).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive_messages(find_issue: nil, create_issue: 1)

        expect { described_class.report(exception, env) }.not_to raise_error
        expect(mock_client).to have_received(:create_issue)
      end
    end

    context "when no existing issue is found" do
      let(:mock_client) { instance_double(Eussiror::GithubClient) }

      before do
        configure_eussiror
        allow(Eussiror::GithubClient).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive_messages(find_issue: nil, create_issue: 1)
      end

      it "creates a new issue" do
        described_class.report(exception, env)

        expect(mock_client).to have_received(:create_issue).with(
          hash_including(title: start_with("[500] RuntimeError"))
        )
      end

      it "includes the exception class in the issue title" do
        described_class.report(exception, env)

        expect(mock_client).to have_received(:create_issue).with(
          hash_including(title: include("RuntimeError"))
        )
      end

      it "includes the fingerprint marker in the issue body" do
        described_class.report(exception, env)

        expect(mock_client).to have_received(:create_issue).with(
          hash_including(body: include(Eussiror::GithubClient::FINGERPRINT_MARKER))
        )
      end

      it "includes request path in the issue body" do
        described_class.report(exception, env)

        expect(mock_client).to have_received(:create_issue).with(
          hash_including(body: include("/dashboard"))
        )
      end

      it "passes configured labels" do
        Eussiror.configuration.labels = %w[bug automated]
        described_class.report(exception, env)

        expect(mock_client).to have_received(:create_issue).with(
          hash_including(labels: %w[bug automated])
        )
      end
    end

    context "when an existing issue is found" do
      let(:mock_client) { instance_double(Eussiror::GithubClient) }

      before do
        configure_eussiror
        allow(Eussiror::GithubClient).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive_messages(find_issue: 42, add_comment: 999, create_issue: 1)
      end

      it "adds a comment to the existing issue" do
        described_class.report(exception, env)

        expect(mock_client).to have_received(:add_comment).with(42, hash_including(:body))
      end

      it "does not create a new issue" do
        described_class.report(exception, env)

        expect(mock_client).not_to have_received(:create_issue)
      end

      it "includes a timestamp in the comment" do
        freeze_time = Time.utc(2026, 2, 26, 10, 30, 0)
        allow(Time).to receive(:now).and_return(freeze_time)

        described_class.report(exception, env)

        expect(mock_client).to have_received(:add_comment).with(
          42,
          body: include("2026-02-26 10:30:00 UTC")
        )
      end
    end

    context "when GitHub client raises an error" do
      let(:mock_client) { instance_double(Eussiror::GithubClient) }

      before do
        configure_eussiror
        allow(Eussiror::GithubClient).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:find_issue).and_raise(StandardError, "API error")
      end

      it "does not propagate the error" do
        expect { described_class.report(exception, env) }.not_to raise_error
      end

      it "emits a warning" do
        expect { described_class.report(exception, env) }.to output(/Eussiror/).to_stderr
      end
    end

    context "when async is true" do
      let(:mock_client) { instance_double(Eussiror::GithubClient) }

      before do
        configure_eussiror(async: true)
        allow(Eussiror::GithubClient).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive_messages(find_issue: nil, create_issue: 1)
      end

      it "spawns a thread and still calls create_issue" do
        thread = described_class.report(exception, env)
        thread.join if thread.is_a?(Thread)

        expect(mock_client).to have_received(:create_issue)
      end
    end
  end

  describe "issue body content" do
    let(:mock_client) { instance_double(Eussiror::GithubClient) }

    before do
      configure_eussiror
      allow(Eussiror::GithubClient).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive_messages(find_issue: nil, create_issue: 1)
    end

    it "omits request info when env is empty" do
      described_class.report(exception, {})

      expect(mock_client).to have_received(:create_issue).with(
        satisfy { |h| !h[:body].include?("**Request:**") }
      )
    end

    it "omits request info when REQUEST_METHOD is missing" do
      described_class.report(exception, { "PATH_INFO" => "/foo" })

      expect(mock_client).to have_received(:create_issue).with(
        satisfy { |h| !h[:body].include?("**Request:**") }
      )
    end

    it "omits REMOTE_ADDR when not present in env" do
      env_without_ip = { "REQUEST_METHOD" => "POST", "PATH_INFO" => "/api/action" }
      described_class.report(exception, env_without_ip)

      expect(mock_client).to have_received(:create_issue).with(
        satisfy { |h|
          h[:body].include?("POST /api/action") && !h[:body].include?("**Remote IP:**")
        }
      )
    end

    it "truncates backtrace to MAX_BACKTRACE_LINES lines" do
      long_backtrace = (1..30).map { |i| "app/models/foo.rb:#{i}:in 'method'" }
      ex = RuntimeError.new("many frames")
      ex.set_backtrace(long_backtrace)

      described_class.report(ex, {})

      expect(mock_client).to have_received(:create_issue).with(
        hash_including(body: satisfy { |b|
          b.scan("app/models/foo.rb").length == Eussiror::ErrorReporter::MAX_BACKTRACE_LINES
        })
      )
    end

    it "uses only the first line of a multiline message in the issue title" do
      multiline_ex = RuntimeError.new("first line\nsecond line\nthird line")
      multiline_ex.set_backtrace(["app/foo.rb:1"])

      described_class.report(multiline_ex, {})

      expect(mock_client).to have_received(:create_issue).with(
        hash_including(title: satisfy { |t| t.include?("first line") && !t.include?("second line") })
      )
    end

    it "truncates the issue title message to 120 characters" do
      long_message = "a" * 150
      ex = RuntimeError.new(long_message)
      ex.set_backtrace(["app/foo.rb:1"])

      described_class.report(ex, {})

      expect(mock_client).to have_received(:create_issue).with(
        hash_including(title: satisfy { |t| t.length <= "[500] RuntimeError: ".length + 120 })
      )
    end
  end

  describe "Eussiror module" do
    it ".configuration returns a Configuration instance" do
      expect(Eussiror.configuration).to be_a(Eussiror::Configuration)
    end

    it ".reset_configuration! returns a fresh Configuration" do
      Eussiror.configuration.github_token = "old_token"
      Eussiror.reset_configuration!
      expect(Eussiror.configuration.github_token).to be_nil
    end

    it ".configuration is memoized (same object returned)" do
      config1 = Eussiror.configuration
      config2 = Eussiror.configuration
      expect(config1).to equal(config2)
    end
  end
end
