# frozen_string_literal: true

require "spec_helper"

RSpec.describe Eussiror::GithubClient do
  subject(:client) { described_class.new(token: "test_token", repository: "owner/repo") }

  let(:api_base) { "https://api.github.com" }
  let(:fingerprint) { "abc123def456" }

  describe "#find_issue" do
    let(:search_url) { /#{Regexp.escape("#{api_base}/search/issues")}/ }

    context "when a matching issue exists" do
      before do
        stub_request(:get, search_url)
          .to_return(
            status: 200,
            body: JSON.generate({ "items" => [{ "number" => 42, "title" => "some issue" }] }),
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns the issue number" do
        expect(client.find_issue(fingerprint)).to eq(42)
      end

      it "sends the correct Authorization header" do
        client.find_issue(fingerprint)
        expect(WebMock).to have_requested(:get, search_url)
          .with(headers: { "Authorization" => "Bearer test_token" })
      end

      it "sends the correct Accept header" do
        client.find_issue(fingerprint)
        expect(WebMock).to have_requested(:get, search_url)
          .with(headers: { "Accept" => "application/vnd.github+json" })
      end

      it "sends the correct GitHub API version header" do
        client.find_issue(fingerprint)
        expect(WebMock).to have_requested(:get, search_url)
          .with(headers: { "X-GitHub-Api-Version" => "2022-11-28" })
      end

      it "sends a User-Agent header containing the gem name" do
        client.find_issue(fingerprint)
        expect(WebMock).to have_requested(:get, search_url)
          .with(headers: { "User-Agent" => /eussiror/ })
      end

      it "sends the correct Content-Type header" do
        client.find_issue(fingerprint)
        expect(WebMock).to have_requested(:get, search_url)
          .with(headers: { "Content-Type" => "application/json" })
      end

      it "embeds the fingerprint marker in the search query" do
        client.find_issue(fingerprint)
        expect(WebMock).to(have_requested(:get, search_url)
          .with { |req| req.uri.query.include?(Eussiror::GithubClient::FINGERPRINT_MARKER) })
      end
    end

    context "when no matching issue exists" do
      before do
        stub_request(:get, search_url)
          .to_return(
            status: 200,
            body: JSON.generate({ "items" => [] }),
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        expect(client.find_issue(fingerprint)).to be_nil
      end
    end

    context "when the API response has nil items" do
      before do
        stub_request(:get, search_url)
          .to_return(
            status: 200,
            body: JSON.generate({}),
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns nil" do
        expect(client.find_issue(fingerprint)).to be_nil
      end
    end

    context "when the API returns an error" do
      before do
        stub_request(:get, search_url)
          .to_return(status: 403, body: JSON.generate({ "message" => "Forbidden" }))
      end

      it "returns nil without raising" do
        expect(client.find_issue(fingerprint)).to be_nil
      end
    end
  end

  describe "#create_issue" do
    let(:create_url) { "#{api_base}/repos/owner/repo/issues" }

    before do
      stub_request(:post, create_url)
        .to_return(
          status: 201,
          body: JSON.generate({ "number" => 7, "html_url" => "https://github.com/owner/repo/issues/7" }),
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns the new issue number" do
      result = client.create_issue(title: "[500] RuntimeError: oops", body: "## Error\ndetails")
      expect(result).to eq(7)
    end

    it "sends the title and body in the request" do
      client.create_issue(title: "my title", body: "my body")

      expect(WebMock).to have_requested(:post, create_url)
        .with(body: hash_including("title" => "my title", "body" => "my body"))
    end

    it "sends the correct Authorization header" do
      client.create_issue(title: "t", body: "b")
      expect(WebMock).to have_requested(:post, create_url)
        .with(headers: { "Authorization" => "Bearer test_token" })
    end

    it "includes labels when provided" do
      client.create_issue(title: "t", body: "b", labels: %w[bug automated])

      expect(WebMock).to have_requested(:post, create_url)
        .with(body: hash_including("labels" => %w[bug automated]))
    end

    it "includes assignees when provided" do
      client.create_issue(title: "t", body: "b", assignees: %w[alice])

      expect(WebMock).to have_requested(:post, create_url)
        .with(body: hash_including("assignees" => %w[alice]))
    end

    it "omits labels key when empty" do
      client.create_issue(title: "t", body: "b", labels: [])

      expect(WebMock).to(have_requested(:post, create_url)
        .with { |req| !JSON.parse(req.body).key?("labels") })
    end

    it "omits assignees key when empty" do
      client.create_issue(title: "t", body: "b", assignees: [])

      expect(WebMock).to(have_requested(:post, create_url)
        .with { |req| !JSON.parse(req.body).key?("assignees") })
    end

    context "when the API returns an error" do
      before do
        stub_request(:post, create_url)
          .to_return(status: 422, body: JSON.generate({ "message" => "Validation Failed" }))
      end

      it "raises an error" do
        expect { client.create_issue(title: "t", body: "b") }.to raise_error(RuntimeError, /create issue/)
      end
    end
  end

  describe "#add_comment" do
    let(:comment_url) { "#{api_base}/repos/owner/repo/issues/42/comments" }

    before do
      stub_request(:post, comment_url)
        .to_return(
          status: 201,
          body: JSON.generate({ "id" => 999 }),
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns the comment id" do
      expect(client.add_comment(42, body: "**New occurrence:** 2026-02-26")).to eq(999)
    end

    it "sends the body in the request" do
      client.add_comment(42, body: "occurrence note")

      expect(WebMock).to have_requested(:post, comment_url)
        .with(body: hash_including("body" => "occurrence note"))
    end

    it "sends the correct Authorization header" do
      client.add_comment(42, body: "note")
      expect(WebMock).to have_requested(:post, comment_url)
        .with(headers: { "Authorization" => "Bearer test_token" })
    end

    context "when the API returns an error" do
      before do
        stub_request(:post, comment_url)
          .to_return(status: 404, body: JSON.generate({ "message" => "Not Found" }))
      end

      it "raises an error" do
        expect { client.add_comment(42, body: "note") }.to raise_error(RuntimeError, /add comment/)
      end
    end
  end
end
