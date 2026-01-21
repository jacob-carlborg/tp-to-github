# frozen_string_literal: true
require "spec_helper"
require "tp_to_github/assignee_utils"

require "rspec"

RSpec.describe TpToGithub::AssigneeUtils do
  let(:mapping) { { "foo@bar.com" => "guser1", "x@y.com" => "gh2" } }

  it "maps emails, warns on missing, dedupes" do
    fake_stderr = StringIO.new
    emails = ["foo@bar.com", "Foo@Bar.com", "missing@xx.com", "x@y.com", "x@y.com"]
    result = described_class.map_tp_emails_to_gh_usernames(emails, mapping, warn_io: fake_stderr)
    expect(result).to contain_exactly("guser1", "gh2")
    fake_stderr.rewind
    warnings = fake_stderr.string
    expect(warnings).to include("No GitHub assignee mapping found for TP user: missing@xx.com")
  end

  it "returns empty if no valid mappings" do
    fake_stderr = StringIO.new
    result = described_class.map_tp_emails_to_gh_usernames(["bad@no.com"], mapping, warn_io: fake_stderr)
    expect(result).to eq([])
    expect(fake_stderr.string).to include("No GitHub assignee mapping found for TP user: bad@no.com")
  end
end
