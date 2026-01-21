# frozen_string_literal: true

module TpToGithub
  class AssigneeMapping
    def self.from_file(file_path)
      mapping = {}
      return mapping unless file_path && File.exist?(file_path)
      File.foreach(file_path) do |line|
        next if line.strip.empty? || line.strip.start_with?("#")
        if (m = line.strip.match(/^([^=]+)=(.+)$/))
          tp_email = m[1].strip.downcase
          gh_user = m[2].strip
          mapping[tp_email] = gh_user unless tp_email.empty? || gh_user.empty?
        end
      end
      mapping
    end
  end
end
