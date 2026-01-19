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
    expect(markdown).to include("<!--tp:UserStory:123-->")
    expect(markdown).to end_with("<!--tp:UserStory:123-->\n")

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

  it "normalizes a generic entity (no tasks list)" do
    entity = {
      "Id" => 50,
      "Name" => "Project",
      "Description" => "<p>Desc</p>"
    }

    normalizer = described_class.new(base_url: "https://example.tpondemand.com")
    normalized = normalizer.normalize_entity(entity, tp_type: "Project")

    expect(normalized.fetch("description_markdown")).to include("Desc")
    expect(normalized.fetch("description_markdown")).not_to include("### Tasks")
    expect(normalized.fetch("description_markdown")).to include("<!--tp:Project:50-->")
    expect(normalized.fetch("description_markdown")).to end_with("<!--tp:Project:50-->\n")
  end

  it "still includes import note with missing description" do
    story = { "Id" => 1, "Name" => "No desc", "Description" => nil }

    normalizer = described_class.new(base_url: "https://example.tpondemand.com")
    normalized = normalizer.normalize(story)

    expect(normalized.fetch("description_markdown")).to include("https://example.tpondemand.com/entity/1")
    expect(normalized.fetch("description_markdown")).to include("<!--tp:UserStory:1-->")
  end
end
