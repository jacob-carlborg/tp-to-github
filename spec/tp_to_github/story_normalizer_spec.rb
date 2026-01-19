# frozen_string_literal: true

require "spec_helper"

RSpec.describe TpToGithub::StoryNormalizer do
  it "normalizes id, name, and converts description to markdown" do
    story = {
      "Id" => 123,
      "Name" => "My Story",
      "Description" => "<p>Hello <strong>world</strong></p>"
    }

    normalized = described_class.new.normalize(story)

    expect(normalized.fetch("id")).to eql(123)
    expect(normalized.fetch("name")).to eql("My Story")
    expect(normalized.fetch("description_markdown")).to include("Hello")
    expect(normalized.fetch("description_markdown")).to include("**world**")
  end

  it "handles missing description" do
    story = { "Id" => 1, "Name" => "No desc", "Description" => nil }

    normalized = described_class.new.normalize(story)

    expect(normalized.fetch("description_markdown")).to eql("")
  end
end
