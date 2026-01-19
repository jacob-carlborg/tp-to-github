# frozen_string_literal: true

require "reverse_markdown"

module TpToGithub
  class StoryNormalizer
    def normalize(raw_story)
      {
        "id" => raw_story.fetch("Id"),
        "name" => raw_story.fetch("Name"),
        "description_markdown" => html_to_markdown(raw_story["Description"])
      }
    end

    private

    def html_to_markdown(html)
      return "" if html.nil? || html.strip.empty?

      ReverseMarkdown.convert(html)
    end
  end
end
