# frozen_string_literal: true

require "json"
require "uri"

require "faraday"

require_relative "config_error"

module TpToGithub
  class TargetProcessClient
    DEFAULT_TAKE = 200

    def initialize(base_url:, username:, password:, connection: nil)
      @base_url = base_url
      @username = username
      @password = password
      @connection = connection

      validate!
    end

    def user_stories(team_id:, take: DEFAULT_TAKE)
      skip = 0
      stories = []

      loop do
        response = connection.get("/api/v1/UserStories") do |req|
          req.params["where"] = "Team.Id eq #{team_id}"
          req.params["select"] = "Id,Name,Description"
          req.params["take"] = take
          req.params["skip"] = skip
        end

        body = JSON.parse(response.body)
        items = body.fetch("Items")

        stories.concat(items)

        break if items.empty?

        skip += take
      end

      stories
    end

    private

    def validate!
      raise ConfigError, "TP_BASE_URL is required" if @base_url.to_s.strip.empty?
      raise ConfigError, "TP_USERNAME is required" if @username.to_s.strip.empty?
      raise ConfigError, "TP_PASSWORD is required" if @password.to_s.strip.empty?

      uri = URI.parse(@base_url)
      raise ConfigError, "TP_BASE_URL must include scheme" if uri.scheme.nil?
    rescue URI::InvalidURIError => e
      raise ConfigError, "TP_BASE_URL is not a valid URL: #{e.message}"
    end

    def connection
      @connection ||= Faraday.new(url: @base_url) do |f|
        f.request :authorization, :basic, @username, @password
        f.headers["Accept"] = "application/json"
        f.headers["User-Agent"] = "tp-to-github"
      end
    end
  end
end
