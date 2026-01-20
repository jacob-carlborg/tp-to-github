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
        data = resp["data"]
        unless data
          raise Error, "GraphQL: missing 'data' in response: #{resp.inspect}"
        end
        org_info = data["organization"]
        unless org_info
          msg = resp["errors"] ? " (errors: #{resp["errors"].map { |e| e["message"] }.join(", ")})" : ""
          raise Error, "Org not found: #{@org}#{msg} | resp: #{resp.inspect}"
        end
        result = org_info["projectsV2"]["nodes"]
        matches = result.select { |n| n["title"] == name }
        if matches.size > 1
          raise Error, "Ambiguous project name: #{name.inspect} (found #{matches.size})"
        elsif matches.size == 1
          return matches.first["id"]
        end
        # else: search next page
        page_info = org_info["projectsV2"]["pageInfo"]
        break unless page_info && page_info["hasNextPage"]
        after = page_info["endCursor"]
      end
      raise Error, "Project not found with name: #{name} in org #{@org}"
    end

    # Adds an issue (by node ID) to a project v2 (by node ID) and returns item ID
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
      resp["data"]["addProjectV2ItemById"]["item"]["id"]
    end

    # Gets all fields for the given project node ID
    def project_fields(project_node_id:)
      resp = graphql(
        query: <<~GQL,
          query($project: ID!) {
            node(id: $project) {
              ... on ProjectV2 {
                fields(first: 50) {
                  nodes {
                    ... on ProjectV2FieldCommon {
                      id
                      name
                    }
                    ... on ProjectV2Field {
                      dataType
                    }
                  }
                }
              }
            }
          }
        GQL
        variables: { project: project_node_id }
      )
      fields_arr = resp.dig("data", "node", "fields", "nodes")
      raise Error, "Project fields not found: #{resp}" unless fields_arr
      fields_arr
    end

    # Gets project item id for issue (issue_node_id) in the project
    def find_project_item_id(project_node_id:, issue_node_id:)
      resp = graphql(
        query: <<~GQL,
          query($project: ID!) {
            node(id: $project) {
              ... on ProjectV2 {
                items(first: 100) {
                  nodes {
                    id
                    content { ... on Issue { id } }
                  }
                }
              }
            }
          }
        GQL
        variables: { project: project_node_id }
      )
      items = resp.dig("data", "node", "items", "nodes")
      raise Error, "Could not list project items: #{resp.inspect}" unless items
      found = items.find { |item| item.dig("content", "id") == issue_node_id }
      raise Error, "Project item for issue not found: #{issue_node_id}" unless found
      found["id"]
    end

    # Updates a number field for a specific item
    def set_estimate_field(project_node_id:, item_id:, field_id:, value:)
      resp = graphql(
        query: <<~GQL,
          mutation($project: ID!, $item: ID!, $field: ID!, $value: Float!) {
            updateProjectV2ItemFieldValue(input: {
              projectId: $project, itemId: $item, fieldId: $field, value: { number: $value }
            }) {
              projectV2Item { id }
            }
          }
        GQL
        variables: { project: project_node_id, item: item_id, field: field_id, value: value.to_f }
      )
      unless resp.dig("data", "updateProjectV2ItemFieldValue", "projectV2Item", "id")
        raise Error, "updateProjectV2ItemFieldValue failed: #{resp.inspect}"
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
