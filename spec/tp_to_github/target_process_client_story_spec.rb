# frozen_string_literal: true

require "spec_helper"

require "webmock/rspec"

RSpec.describe TpToGithub::TargetProcessClient do
  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  it "fetches a single user story by id" do
    base_url = "https://example.tpondemand.com"

    stub_request(:get, "#{base_url}/api/v1/UserStories/36406")
      .with(query: { "select" => "Id,Name,Description" })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate({ "Id" => 36_406, "Name" => "Story", "Description" => "<p>Hi</p>" })
      )

    client = described_class.new(base_url:, username: "u", password: "p")

    story = client.user_story(id: 36_406)

    expect(story.fetch("Id")).to eql(36_406)
  end
end
