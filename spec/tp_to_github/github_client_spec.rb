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
end
