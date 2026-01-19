# frozen_string_literal: true

require "spec_helper"

require "webmock/rspec"

RSpec.describe TpToGithub::TargetProcessClient do
  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  it "raises if base_url is missing" do
    expect do
      described_class.new(base_url: "", username: "u", password: "p")
    end.to raise_error(TpToGithub::ConfigError, /TP_BASE_URL is required/)
  end

  it "raises if base_url is invalid" do
    expect do
      described_class.new(base_url: "not a url", username: "u", password: "p")
    end.to raise_error(TpToGithub::ConfigError, /TP_BASE_URL is not a valid URL/)
  end

  it "fetches team user stories with pagination" do
    base_url = "https://example.tpondemand.com"
    team_id = 35_411

    stub_request(:get, "#{base_url}/api/v1/UserStories")
      .with(
        query: {
          "where" => "Team.Id eq #{team_id}",
          "select" => "Id,Name,Description",
          "take" => "2",
          "skip" => "0"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Items" => [{ "Id" => 1 }, { "Id" => 2 }] })
      )

    stub_request(:get, "#{base_url}/api/v1/UserStories")
      .with(
        query: {
          "where" => "Team.Id eq #{team_id}",
          "select" => "Id,Name,Description",
          "take" => "2",
          "skip" => "2"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Items" => [] })
      )

    client = described_class.new(base_url:, username: "u", password: "p")

    stories = client.user_stories(team_id:, take: 2)

    expect(stories).to eql([{ "Id" => 1 }, { "Id" => 2 }])
  end
end
