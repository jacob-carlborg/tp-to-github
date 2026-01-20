# frozen_string_literal: true

require "base64"

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

         content = @tp_client.download_attachment(att_id)
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

