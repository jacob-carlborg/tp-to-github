# frozen_string_literal: true

require "json"

require "cgi"
require "base64"

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

      if response.success?
        return true
      end

      if response.status == 422 && duplicate_or_has_parent_error?(response.body)
        return false
      end

      raise Error, "GitHub add sub-issue failed (status=#{response.status}): #{response.body}"
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

    def find_issue_by_marker(tp_type:, tp_id:)
      marker = "<!--tp:#{tp_type}:#{tp_id}-->"
      query = "repo:#{@repo} in:body \"#{marker}\""

      response = connection.get("/search/issues") do |req|
        req.params["q"] = query
        req.params["per_page"] = 1
      end

      unless response.success?
        raise Error, "GitHub issue search failed (status=#{response.status}): #{response.body}"
      end

      body = JSON.parse(response.body)
      item = body.fetch("items", []).first
      item
    end

    def file_exists?(path:, ref:)
      response = connection.get("/repos/#{@repo}/contents/#{cgi_escape_path(path)}") do |req|
        req.params["ref"] = ref
      end

      return true if response.success?
      return false if response.status == 404

      raise Error, "GitHub content lookup failed (status=#{response.status}): #{response.body}"
    end

    def upload_file(path:, content:, branch:, message:)
      return false if file_exists?(path:, ref: branch)

      base64_content = Base64.strict_encode64(content)

      response = connection.put("/repos/#{@repo}/contents/#{cgi_escape_path(path)}") do |req|
        req.body = JSON.generate({ message:, content: base64_content, branch: })
      end

      unless response.success?
        raise Error, "GitHub upload file failed (status=#{response.status}): #{response.body}"
      end

      true
    end

    private

    def cgi_escape_path(path)
      path.split("/").map { |part| CGI.escape(part) }.join("/")
    end

    def duplicate_or_has_parent_error?(response_body)
      body = JSON.parse(response_body)
      message = body["message"].to_s

      message.include?("duplicate sub-issues") || message.include?("only have one parent")
    rescue JSON::ParserError
      false
    end

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
