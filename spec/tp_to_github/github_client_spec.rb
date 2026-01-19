# frozen_string_literal: true

require "spec_helper"

require "webmock/rspec"

RSpec.describe TpToGithub::GitHubClient do
  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  it "creates an issue" do
    stub_request(:post, "https://api.github.com/repos/octo-org/octo-repo/issues")
      .with(
        body: { title: "Hello", body: "World" }.to_json,
        headers: {
          "Accept" => "application/vnd.github+json",
          "Authorization" => "Bearer token",
          "Content-Type" => "application/json",
          "X-Github-Api-Version" => "2022-11-28"
        }
      )
      .to_return(
        status: 201,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "number" => 123, "html_url" => "https://github.com/octo-org/octo-repo/issues/123" })
      )

    client = described_class.new(access_token: "token", repo: "octo-org/octo-repo")

    created = client.create_issue(title: "Hello", body: "World")

    expect(created.fetch("number")).to eql(123)
  end

  it "adds a sub-issue" do
    stub_request(:post, "https://api.github.com/repos/octo-org/octo-repo/issues/10/sub_issues")
      .with(
        body: { sub_issue_id: 999 }.to_json,
        headers: {
          "Accept" => "application/vnd.github+json",
          "Authorization" => "Bearer token",
          "Content-Type" => "application/json",
          "X-Github-Api-Version" => "2022-11-28"
        }
      )
      .to_return(status: 201, body: "{}")

    client = described_class.new(access_token: "token", repo: "octo-org/octo-repo")

    expect(client.add_sub_issue(parent_issue_number: 10, child_issue_id: 999)).to be(true)
  end

  it "returns false when sub-issue already linked" do
    stub_request(:post, "https://api.github.com/repos/octo-org/octo-repo/issues/10/sub_issues")
      .to_return(
        status: 422,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "message" => "An error occurred while adding the sub-issue to the parent issue. Issue may not contain duplicate sub-issues and Sub issue may only have one parent" })
      )

    client = described_class.new(access_token: "token", repo: "octo-org/octo-repo")

    expect(client.add_sub_issue(parent_issue_number: 10, child_issue_id: 999)).to be(false)
  end

  it "mutes an issue" do
    stub_request(:put, "https://api.github.com/repos/octo-org/octo-repo/issues/10/subscription")
      .with(
        body: { subscribed: false, ignored: true }.to_json,
        headers: {
          "Accept" => "application/vnd.github+json",
          "Authorization" => "Bearer token",
          "Content-Type" => "application/json",
          "X-Github-Api-Version" => "2022-11-28"
        }
      )
      .to_return(status: 200, body: "{}")

    client = described_class.new(access_token: "token", repo: "octo-org/octo-repo")

    expect(client.mute_issue(issue_number: 10)).to be(true)
  end

  it "finds an issue by TP marker" do
    stub_request(:get, "https://api.github.com/search/issues")
      .with(
        query: {
          "q" => "repo:octo-org/octo-repo in:body \"<!--tp:Project:35256-->\"",
          "per_page" => "1"
        },
        headers: {
          "Accept" => "application/vnd.github+json",
          "Authorization" => "Bearer token",
          "Content-Type" => "application/json",
          "X-Github-Api-Version" => "2022-11-28"
        }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "items" => [{ "number" => 1, "id" => 99 }] })
      )

    client = described_class.new(access_token: "token", repo: "octo-org/octo-repo")

    found = client.find_issue_by_marker(tp_type: "Project", tp_id: 35_256)

    expect(found.fetch("id")).to eql(99)
  end
end
