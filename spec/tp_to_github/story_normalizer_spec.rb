# frozen_string_literal: true

require "spec_helper"

RSpec.describe TpToGithub::StoryNormalizer do
  it "adds tasks before import note" do
    story = {
      "Id" => 123,
      "Name" => "My Story",
      "Description" => "<div><p>Hello <strong>world</strong></p></div>"
    }

    tasks = [{ "Name" => "Task A" }, { "Name" => "Task B" }]

    normalizer = described_class.new(base_url: "https://example.tpondemand.com")
    normalized = normalizer.normalize(story, tasks:)

    expect(normalized.fetch("id")).to eql(123)
    expect(normalized.fetch("name")).to eql("My Story")
    markdown = normalized.fetch("description_markdown")

    expect(markdown).to include("Hello")
    expect(markdown).to include("**world**")
    expect(markdown).to include("### Tasks\n- [ ] Task A\n- [ ] Task B")
    expect(markdown).to end_with("_Imported from TargetProcess: [#123](https://example.tpondemand.com/entity/123)_\n")

    expect(markdown.index("### Tasks")).to be > markdown.index("Hello")
    expect(markdown.index("_Imported from TargetProcess")).to be > markdown.index("### Tasks")
  end

  it "does not convert when description is already markdown" do
    story = {
      "Id" => 999,
      "Name" => "Already MD",
      "Description" => "<!--markdown--># Title\n\n- item"
    }

    normalizer = described_class.new(base_url: "https://example.tpondemand.com")
    normalized = normalizer.normalize(story)

    markdown = normalized.fetch("description_markdown")
    expect(markdown).to include("# Title")
    expect(markdown).to include("- item")
  end

  it "still includes import note with missing description" do
    story = { "Id" => 1, "Name" => "No desc", "Description" => nil }

    normalizer = described_class.new(base_url: "https://example.tpondemand.com")
    normalized = normalizer.normalize(story)

    expect(normalized.fetch("description_markdown")).to include("https://example.tpondemand.com/entity/1")
  end
end
