# frozen_string_literal: true

require "base64"
require "json"

  module TpToGithub
  class AttachmentUploader
    def initialize(tp_client:, github_client:, repo:, branch: nil)
      @tp_client = tp_client
      @github_client = github_client
      @repo = repo
      @branch = branch || github_client.default_branch


      validate!
    end

    def upload_attachments(tp_type:, tp_entity_id:, dry_run:)
      attachments = @tp_client.attachments_for(tp_type:, entity_id: tp_entity_id)

      results = []

      attachments.each do |att|
        att_id = att.fetch("Id")
        original_name = att["Name"].to_s
        ext = File.extname(original_name)

        filename = "#{att_id}#{ext}"
        path = "tp_attachments/#{tp_type}/#{tp_entity_id}/#{filename}"

         results << {
           "tp_attachment_id" => att_id,
           "original_name" => original_name,
           "path" => path,
           "url" => build_blob_url(path)
         }


         next if dry_run

         if ENV["TP_DEBUG"] == "1"
           warn "[tp-to-github] Uploading attachment: tp_type=#{tp_type} tp_entity_id=#{tp_entity_id} attachment_id=#{att_id} path=#{path}"
         end

         content = @tp_client.download_attachment(att_id)

         if ENV["TP_DEBUG"] == "1"
           require "digest"
           sha = Digest::SHA256.hexdigest(content)
           sample = content[0, 80]
           warn "[tp-to-github] Attachment debug after download: path=#{path} sha256=#{sha} first80=#{sample.inspect}"
         end

         if content.is_a?(String)
           stripped = content.lstrip
           if stripped.start_with?("{")
             begin
               parsed = JSON.parse(stripped)
               if parsed.is_a?(Hash) && parsed.key?("Status") && parsed.key?("Message")
                 raise "Refusing to upload TargetProcess error payload for attachment #{att_id}: #{parsed["Message"]}"
               end
             rescue JSON::ParserError
               nil
             end
           end
         end

         @github_client.upload_file(path:, content:, branch: @branch, message: "Import TP attachment #{tp_type}##{tp_entity_id} (#{att_id})")

       end

       results
     end

     def build_blob_url(path)
       "https://github.com/#{@repo}/blob/#{@branch}/#{path}"
     end

     private

     def validate!
       raise ArgumentError, "repo is required" if @repo.to_s.strip.empty?
     end
   end
 end

