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

  it "fetches team user stories with pagination (excluding Done)" do
    base_url = "https://example.tpondemand.com"
    team_id = 35_411

    stub_request(:get, "#{base_url}/api/v1/UserStories")
      .with(
        query: {
          "where" => "Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
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
          "where" => "Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
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

  it "fetches team projects (excluding Done)" do
    base_url = "https://example.tpondemand.com"
    team_id = 35_411

    stub_request(:get, "#{base_url}/api/v1/Projects")
      .with(
        query: {
          "where" => "Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
          "select" => "Id,Name,Description",
          "take" => "1",
          "skip" => "0"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Items" => [{ "Id" => 10 }] })
      )

    stub_request(:get, "#{base_url}/api/v1/Projects")
      .with(
        query: {
          "where" => "Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
          "select" => "Id,Name,Description",
          "take" => "1",
          "skip" => "1"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Items" => [] })
      )

    client = described_class.new(base_url:, username: "u", password: "p")

    projects = client.projects(team_id:, take: 1)

    expect(projects).to eql([{ "Id" => 10 }])
  end

  it "fetches team epics (excluding Done)" do
    base_url = "https://example.tpondemand.com"
    team_id = 35_411

    stub_request(:get, "#{base_url}/api/v1/Epics")
      .with(
        query: {
          "where" => "Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
          "select" => "Id,Name,Description",
          "take" => "1",
          "skip" => "0"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Items" => [{ "Id" => 20 }] })
      )

    stub_request(:get, "#{base_url}/api/v1/Epics")
      .with(
        query: {
          "where" => "Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
          "select" => "Id,Name,Description",
          "take" => "1",
          "skip" => "1"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Items" => [] })
      )

    client = described_class.new(base_url:, username: "u", password: "p")

    epics = client.epics(team_id:, take: 1)

    expect(epics).to eql([{ "Id" => 20 }])
  end

  it "fetches team features (excluding Done)" do
    base_url = "https://example.tpondemand.com"
    team_id = 35_411

    stub_request(:get, "#{base_url}/api/v1/Features")
      .with(
        query: {
          "where" => "Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
          "select" => "Id,Name,Description",
          "take" => "1",
          "skip" => "0"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Items" => [{ "Id" => 30 }] })
      )

    stub_request(:get, "#{base_url}/api/v1/Features")
      .with(
        query: {
          "where" => "Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
          "select" => "Id,Name,Description",
          "take" => "1",
          "skip" => "1"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Items" => [] })
      )

    client = described_class.new(base_url:, username: "u", password: "p")

    features = client.features(team_id:, take: 1)

    expect(features).to eql([{ "Id" => 30 }])
  end

  it "fetches child tasks for a user story (excluding Done and team filtered)" do
    base_url = "https://example.tpondemand.com"
    team_id = 35_411
    story_id = 10

    stub_request(:get, "#{base_url}/api/v1/Tasks")
      .with(
        query: {
          "where" => "UserStory.Id eq #{story_id} and UserStory.Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
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

    stub_request(:get, "#{base_url}/api/v1/Tasks")
      .with(
        query: {
          "where" => "UserStory.Id eq #{story_id} and UserStory.Team.Id eq #{team_id} and EntityState.Name ne 'Done'",
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

    tasks = client.tasks_for_user_story(story_id:, team_id:, take: 2)

    expect(tasks).to eql([{ "Id" => 1 }, { "Id" => 2 }])
  end

  it "lists and downloads attachments for an entity" do
    base_url = "https://example.tpondemand.com"

    stub_request(:get, "#{base_url}/api/v1/Attachments")
      .with(
        query: {
          "where" => "General.Id eq 123 and General.EntityType.Name eq 'UserStory'",
          "select" => "Id,Name,Description",
          "take" => "2",
          "skip" => "0"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Items" => [{ "Id" => 1, "Name" => "doc.pdf" }] })
      )

    stub_request(:get, "#{base_url}/api/v1/Attachments")
      .with(
        query: {
          "where" => "General.Id eq 123 and General.EntityType.Name eq 'UserStory'",
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

    stub_request(:get, "#{base_url}/api/v1/Attachments/1")
      .with(query: { "select" => "Id,UniqueFileName" })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Id" => 1, "UniqueFileName" => "attachment_1.pdf" })
      )

    stub_request(:get, "#{base_url}/attachment.aspx")
      .with(
        query: { "attachmentId" => "1", "filename" => "attachment_1.pdf" },
        headers: { "Accept-Encoding" => "identity" }
      )
      .to_return(status: 200, body: "PDFDATA")

    client = described_class.new(base_url:, username: "u", password: "p")

    expect(client.attachments_for(tp_type: "UserStory", entity_id: 123, take: 2)).to eql([{ "Id" => 1, "Name" => "doc.pdf" }])
    body = client.download_attachment(1)

    expect(body).to eql("PDFDATA")
    expect(body.encoding).to eql(Encoding::BINARY)
  end
end
