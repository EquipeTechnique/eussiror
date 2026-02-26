# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Eussiror
  class GithubClient
    GITHUB_API_BASE = "https://api.github.com"
    # Marker embedded as an HTML comment in every issue body for searching.
    FINGERPRINT_MARKER = "eussiror:fingerprint"

    def initialize(token:, repository:)
      @token      = token
      @repository = repository
    end

    # Searches for an open issue whose body contains the given fingerprint.
    # Returns the issue number (Integer) or nil when none is found.
    def find_issue(fingerprint)
      query  = "repo:#{@repository} is:issue is:open \"#{FINGERPRINT_MARKER}:#{fingerprint}\" in:body"
      params = URI.encode_www_form(q: query, per_page: 1)
      uri    = URI("#{GITHUB_API_BASE}/search/issues?#{params}")

      response = get(uri)
      data     = JSON.parse(response.body)

      return nil unless response.is_a?(Net::HTTPSuccess)
      return nil if data["items"].nil? || data["items"].empty?

      data["items"].first["number"]
    end

    # Creates a new GitHub issue and returns the issue number.
    def create_issue(title:, body:, labels: [], assignees: [])
      uri     = URI("#{GITHUB_API_BASE}/repos/#{@repository}/issues")
      payload = { title: title, body: body }
      payload[:labels]    = labels    if labels.any?
      payload[:assignees] = assignees if assignees.any?

      response = post(uri, payload)
      data     = JSON.parse(response.body)

      raise_api_error!(response, "create issue") unless response.is_a?(Net::HTTPSuccess)

      data["number"]
    end

    # Adds a comment to an existing issue. Returns the comment id.
    def add_comment(issue_number, body:)
      uri = URI("#{GITHUB_API_BASE}/repos/#{@repository}/issues/#{issue_number}/comments")

      response = post(uri, { body: body })
      data     = JSON.parse(response.body)

      raise_api_error!(response, "add comment") unless response.is_a?(Net::HTTPSuccess)

      data["id"]
    end

    private

    def get(uri)
      request = Net::HTTP::Get.new(uri)
      apply_headers!(request)
      execute(uri, request)
    end

    def post(uri, payload)
      request = Net::HTTP::Post.new(uri)
      apply_headers!(request)
      request.body = JSON.generate(payload)
      execute(uri, request)
    end

    def execute(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
    end

    def apply_headers!(request)
      request["Authorization"]        = "Bearer #{@token}"
      request["Accept"]               = "application/vnd.github+json"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      request["Content-Type"]         = "application/json"
      request["User-Agent"]           = "eussiror/#{Eussiror::VERSION}"
    end

    def raise_api_error!(response, action)
      raise "Eussiror: GitHub API failed to #{action} " \
            "(HTTP #{response.code}): #{response.body}"
    end
  end
end
