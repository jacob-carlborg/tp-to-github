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
      fetch_collection(
        "/api/v1/UserStories",
        where: where_team_not_done("Team.Id", team_id),
        take:
      )
    end

    def projects(team_id:, take: DEFAULT_TAKE)
      fetch_collection(
        "/api/v1/Projects",
        where: where_team_not_done("Team.Id", team_id),
        take:
      )
    end

    def epics(team_id:, take: DEFAULT_TAKE)
      fetch_collection(
        "/api/v1/Epics",
        where: where_team_not_done("Team.Id", team_id),
        take:
      )
    end

    def features(team_id:, take: DEFAULT_TAKE)
      fetch_collection(
        "/api/v1/Features",
        where: where_team_not_done("Team.Id", team_id),
        take:
      )
    end

    def tasks_for_user_story(story_id:, team_id:, take: DEFAULT_TAKE)
      fetch_collection(
        "/api/v1/Tasks",
        where: "UserStory.Id eq #{story_id} and #{where_team_not_done('UserStory.Team.Id', team_id)}",
        take:
      )
    end

    def user_story(id:)
      response = connection.get("/api/v1/UserStories/#{id}") do |req|
        req.params["select"] = select_fields
      end

      JSON.parse(response.body)
    end

    private

    def select_fields
      "Id,Name,Description"
    end

    def where_team_not_done(team_field, team_id)
      "#{team_field} eq #{team_id} and EntityState.Name ne 'Done'"
    end

    def fetch_collection(path, where:, take:)
      skip = 0
      items = []

      loop do
        response = connection.get(path) do |req|
          req.params["where"] = where
          req.params["select"] = select_fields
          req.params["take"] = take
          req.params["skip"] = skip
        end

        body = JSON.parse(response.body)
        page_items = body.fetch("Items")
        items.concat(page_items)

        break if page_items.empty?

        skip += take
      end

      items
    end

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
