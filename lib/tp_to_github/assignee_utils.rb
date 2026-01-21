# frozen_string_literal: true
require_relative "assignee_mapping"

module TpToGithub
  module AssigneeUtils
    def self.map_tp_emails_to_gh_usernames(tp_emails, mapping, warn_io: $stderr)
      result = []
      tp_emails.each do |email|
        email_down = email.to_s.strip.downcase
        gh_username = mapping[email_down]
        if gh_username && !gh_username.empty?
          result << gh_username
        else
          warn_io.puts("[tp-to-github] WARNING: No GitHub assignee mapping found for TP user: #{email}")
        end
      end
      result.uniq
    end
  end
end
