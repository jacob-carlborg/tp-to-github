# frozen_string_literal: true
require "spec_helper"
require "tp_to_github/assignee_mapping"
require "tempfile"

def tmpfile_with_content(content)
  f = Tempfile.new("assignee_map")
  f.write(content)
  f.rewind
  f
end

RSpec.describe TpToGithub::AssigneeMapping do
  let(:klass) { described_class }

  it "parses valid mapping lines, skips comments and blanks" do
    tmp = tmpfile_with_content(<<~MAP)
      # test map
      user1@foo.com=ghuser1
      user2@foo.com = ghuser2
      
      # Blank line above
      user3@foo.com=ghuser3
    MAP
    expect(klass.from_file(tmp.path)).to eq({
      "user1@foo.com" => "ghuser1",
      "user2@foo.com" => "ghuser2",
      "user3@foo.com" => "ghuser3"
    })
    tmp.close!
  end

  it "returns empty hash for nil or missing file" do
    expect(klass.from_file(nil)).to eq({})
    expect(klass.from_file("/NO_SUCH_FILE_PATH/assignee")).to eq({})
  end

  it "skips lines without = sign or with missing values" do
    tmp = tmpfile_with_content("user@foo.com=\ninvalidrow\n=ghuser\n")
    expect(klass.from_file(tmp.path)).to eq({})
    tmp.close!
  end
end
