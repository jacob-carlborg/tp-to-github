# frozen_string_literal: true

require "json"

require_relative "lib/tp_to_github"

team_id = 35_411
base_url = ENV.fetch("TP_BASE_URL", "")
username = ENV.fetch("TP_USERNAME", "")
password = ENV.fetch("TP_PASSWORD", "")

client = TpToGithub::TargetProcessClient.new(base_url:, username:, password:)
normalizer = TpToGithub::StoryNormalizer.new

stories = client.user_stories(team_id:)
normalized = stories.map { |s| normalizer.normalize(s) }

puts JSON.pretty_generate(normalized)
