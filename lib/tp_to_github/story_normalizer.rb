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

    def normalize(raw_story, tasks: [], attachments: [])
      id = raw_story.fetch("Id")
      description_markdown = html_to_markdown(raw_story["Description"])

      {
        "id" => id,
        "name" => raw_story.fetch("Name"),
        "description_markdown" => build_description(
          tp_type: "UserStory",
          id:,
          description_markdown:,
          tasks:,
          attachments:
        )
      }
    end

    def normalize_entity(raw_entity, tp_type:, attachments: [])
      id = raw_entity.fetch("Id")
      description_markdown = html_to_markdown(raw_entity["Description"])

      {
        "id" => id,
        "name" => raw_entity.fetch("Name"),
        "description_markdown" => build_description(
          tp_type:,
          id:,
          description_markdown:,
          tasks: [],
          attachments:
        )
      }
    end

    private

    def build_description(tp_type:, id:, description_markdown:, tasks:, attachments:)
      parts = []
      parts << description_markdown unless description_markdown.empty?

      task_list = build_task_list(tasks)
      parts << task_list unless task_list.empty?

      attachments_list = build_attachments_list(attachments)
      parts << attachments_list unless attachments_list.empty?

      parts << import_note(id:)
      parts << tp_marker(tp_type:, id:)

      parts.join("\n\n") + "\n"
    end

    def tp_marker(tp_type:, id:)
      "<!--tp:#{tp_type}:#{id}-->"
    end

    def build_task_list(tasks)
      names = tasks.filter_map { |t| t["Name"]&.strip }.reject(&:empty?)
      return "" if names.empty?

      (["### Tasks"] + names.map { |name| "- [ ] #{name}" }).join("\n")
    end

    def build_attachments_list(attachments)
      items = attachments.filter_map do |att|
        name = att["original_name"].to_s.strip
        url = att["url"].to_s.strip
        next if name.empty? || url.empty?

        "- [#{name}](#{url})"
      end

      return "" if items.empty?

      (["### Attachments"] + items).join("\n")
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
