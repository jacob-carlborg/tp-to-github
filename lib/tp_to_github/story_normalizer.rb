# frozen_string_literal: true

require "reverse_markdown"

module TpToGithub
  module ReverseMarkdownConverters
    class Div < ReverseMarkdown::Converters::Base
      def convert(node, state = {})
        treat_children(node, state)
      end
    end
  end

  ReverseMarkdown::Converters.register :div, ReverseMarkdownConverters::Div.new

  class StoryNormalizer
    def initialize(base_url: ENV.fetch("TP_BASE_URL", ""))
      @base_url = base_url
    end

    def normalize(raw_story)
      id = raw_story.fetch("Id")
      description_markdown = html_to_markdown(raw_story["Description"])

      {
        "id" => id,
        "name" => raw_story.fetch("Name"),
        "description_markdown" => build_description(id:, description_markdown:)
      }
    end

    private

    def build_description(id:, description_markdown:)
      parts = []
      parts << description_markdown unless description_markdown.empty?
      parts << import_note(id:)
      parts.join("\n\n") + "\n"
    end

    def import_note(id:)
      url = story_url(id:)
      "_Imported from TargetProcess: [##{id}](#{url})_"
    end

    def story_url(id:)
      base = @base_url.to_s.strip
      return "" if base.empty?

      base = base.delete_suffix("/")
      "#{base}/entity/#{id}"
    end

    def html_to_markdown(html)
      return "" if html.nil? || html.strip.empty?

      stripped = html.lstrip
      return strip_markdown_marker(stripped) if stripped.start_with?("<!--markdown-->")

      ReverseMarkdown.convert(html)
    end

    def strip_markdown_marker(text)
      text.sub(/\A\s*<!--markdown-->\s*/m, "")
    end
  end
end
