# frozen_string_literal: true

require "json"
require "faraday"

module TpToGithub
  class GitHubProjectClient
    class Error < StandardError; end

    def initialize(access_token:, org:, api_base_url: "https://api.github.com/graphql", connection: nil)
      @access_token = access_token
      @org = org
      @api_base_url = api_base_url
      @connection = connection
      validate!
    end

    # Returns project node ID for the project with exact name, or raises
    def project_node_id_by_name(name)
      after = nil
      loop do
        resp = graphql(
          query: <<~GQL,
            query($org: String!, $after: String) {
              organization(login: $org) {
                projectsV2(first: 100, after: $after) {
                  pageInfo { hasNextPage endCursor }
                  nodes { id title }
                }
              }
            }
          GQL
          variables: { org: @org, after: after }
        )
        org = resp["data"]["organization"]
        raise Error, "Org not found: #{@org}" unless org
        result = org["projectsV2"]["nodes"]
        matches = result.select { |n| n["title"] == name }
        if matches.size > 1
          raise Error, "Ambiguous project name: #{name.inspect} (found #{matches.size})"
        elsif matches.size == 1
          return matches.first["id"]
        end
        # else: search next page
        page_info = org["projectsV2"]["pageInfo"]
        break unless page_info && page_info["hasNextPage"]
        after = page_info["endCursor"]
      end
      raise Error, "Project not found with name: #{name} in org #{@org}"
    end

    # Adds an issue (by node ID) to a project v2 (by node ID)
    def add_item_to_project(project_node_id:, issue_node_id:)
      resp = graphql(
        query: <<~GQL,
          mutation($project: ID!, $content: ID!) {
            addProjectV2ItemById(input: {projectId: $project, contentId: $content}) {
              item { id }
            }
          }
        GQL
        variables: { project: project_node_id, content: issue_node_id }
      )
      unless resp["data"] && resp["data"]["addProjectV2ItemById"]
        raise Error, "addProjectV2ItemById failed: #{resp}"
      end
      true
    end

    # Looks up issue node id from issue_number (repo-level)
    def issue_node_id(owner:, repo:, number:)
      resp = graphql(
        query: <<~GQL,
          query($owner: String!, $repo: String!, $number: Int!) {
            repository(owner: $owner, name: $repo) {
              issue(number: $number) { id }
            }
          }
        GQL
        variables: { owner: owner, repo: repo, number: number }
      )
      repo_data = resp["data"]["repository"]
      raise Error, "Repository not found: #{owner}/#{repo}" unless repo_data
      issue_data = repo_data["issue"]
      raise Error, "Issue ##{number} not found" unless issue_data
      issue_data["id"]
    end

    private

    def graphql(query:, variables: {})
      response = connection.post do |req|
        req.headers["Authorization"] = "bearer #{@access_token}"
        req.headers["Content-Type"] = "application/json"
        req.body = JSON.pretty_generate({ query: query, variables: variables })
      end
      raise Error, "GraphQL query failed (status=#{response.status}): #{response.body}" unless response.success?
      JSON.parse(response.body)
    end

    def connection
      @connection ||= Faraday.new(url: @api_base_url)
    end

    def validate!
      raise Error, "ORG is required" if @org.to_s.strip.empty?
      raise Error, "GITHUB_ACCESS_TOKEN is required" if @access_token.to_s.strip.empty?
    end
  end
end
