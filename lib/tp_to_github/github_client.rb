# frozen_string_literal: true

require "json"

require "faraday"

module TpToGithub
  class GitHubClient
    class Error < StandardError; end

    def initialize(access_token:, repo:, api_base_url: "https://api.github.com", connection: nil)
      @access_token = access_token
      @repo = repo
      @api_base_url = api_base_url
      @connection = connection

      validate!
    end

    def create_issue(title:, body:)
      response = connection.post("/repos/#{@repo}/issues") do |req|
        req.body = JSON.generate({ title:, body: })
      end

      unless response.success?
        raise Error, "GitHub create issue failed (status=#{response.status}): #{response.body}"
      end

      JSON.parse(response.body)
    end

    def add_sub_issue(parent_issue_number:, child_issue_id:)
      response = connection.post("/repos/#{@repo}/issues/#{parent_issue_number}/sub_issues") do |req|
        req.body = JSON.generate({ sub_issue_id: child_issue_id })
      end

      unless response.success?
        raise Error, "GitHub add sub-issue failed (status=#{response.status}): #{response.body}"
      end

      true
    end

    def mute_issue(issue_number:)
      response = connection.put("/repos/#{@repo}/issues/#{issue_number}/subscription") do |req|
        req.body = JSON.generate({ subscribed: false, ignored: true })
      end

      unless response.success?
        raise Error, "GitHub mute issue failed (status=#{response.status}): #{response.body}"
      end

      true
    end

    private

    def validate!
      raise Error, "GITHUB_ACCESS_TOKEN is required" if @access_token.to_s.strip.empty?
      raise Error, "GITHUB_REPO is required" if @repo.to_s.strip.empty?
    end

    def connection
      @connection ||= Faraday.new(url: @api_base_url) do |f|
        f.headers["Accept"] = "application/vnd.github+json"
        f.headers["Authorization"] = "Bearer #{@access_token}"
        f.headers["X-GitHub-Api-Version"] = "2022-11-28"
        f.headers["User-Agent"] = "tp-to-github"
        f.headers["Content-Type"] = "application/json"
      end
    end
  end
end
