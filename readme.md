# tp-to-github

A Ruby CLI tool to migrate hierarchical work items from TargetProcess (TP) to GitHub, preserving structure, checklists, attachments, and relationships as GitHub issues with sub-issues.

## Features
- Imports TP user stories, features, epics, projects (entire parent chain) for a team.
- Maps TargetProcess hierarchy to GitHub issues and sub-issues.
- Idempotent by default (won't duplicate imports).
- Supports project v2 field sync (status, estimate, etc). 
- Handles attachments as repo blobs; embeds TP tasks as checklists.
- Supports DRY_RUN (dry-run plan output) and soft-fails on errors.

## Prerequisites
- Ruby ≥ 3.0
- API access to TargetProcess (basic auth)
- API access to GitHub (personal access token)

## Environment Variables
Required for all imports:
- `TP_BASE_URL` — TargetProcess API base URL
- `TP_USERNAME` / `TP_PASSWORD` — TargetProcess credentials
- `GITHUB_REPO` — Destination repo, e.g., `myorg/projectrepo`
- `GITHUB_ACCESS_TOKEN` — GitHub token with required repo/project permissions
- `TP_TEAM_NAME` — (Recommended) TargetProcess team name (preferred if set)
- `TP_TEAM_ID` — Team numeric ID (used if TP_TEAM_NAME unset)
- `DRY_RUN` — set to `1` for dry-run (no API changes, plan output)
- `IDEMPOTENT` — set to `0` to force re-import, otherwise imports only new items
- `GITHUB_PROJECT_NAME` — Name of your GitHub Projects v2 (for field sync), optional

For single-story import:
- `TP_STORY_ID` — Numeric TargetProcess user story ID


## Usage

### Import a Single Story
```
TP_BASE_URL="..." TP_USERNAME=... TP_PASSWORD=... GITHUB_REPO=... GITHUB_ACCESS_TOKEN=... TP_STORY_ID=12345 bin/tp_import_one_issue
```
- This imports the specified UserStory and all its parents into GitHub, uploading checklists/attachments, and linking as sub-issues.

### Import All Stories for a Team
With team name:
```
TP_BASE_URL="..." TP_USERNAME=... TP_PASSWORD=... GITHUB_REPO=... GITHUB_ACCESS_TOKEN=... TP_TEAM_NAME='My TP Team' bin/tp_import_all_issues
```
Or with team ID:
```
TP_TEAM_ID=12345 ... bin/tp_import_all_issues
```
- Imports all user stories (and their parent chains) for the given team that are NOT Done.

### Dry Run / Plan
Add `DRY_RUN=1` to output a plan instead of executing:
```
DRY_RUN=1 ... bin/tp_import_one_issue
DRY_RUN=1 ... bin/tp_import_all_issues
```

### Idempotency
- By default, the tool avoids duplicating previously-imported items.
- To force re-import of everything, set `IDEMPOTENT=0`.

## Error Handling
- If any attachment or issue fails to upload/mute, the script continues with others (soft-fail).
- All errors are printed to stderr for auditing.

## Project Structure
- Executables: `bin/`
- Core logic: `lib/tp_to_github/`
- All code is modular for CLI and testability.

## Example: Import all open stories for a team
```
export TP_BASE_URL="https://mycompany.tpondemand.com"
export TP_USERNAME="my-user@company.com"
export TP_PASSWORD="MY_PASSWORD"
export GITHUB_REPO="myorg/myrepo"
export GITHUB_ACCESS_TOKEN="ghp_SOME_TOKEN"
export TP_TEAM_ID=35411
bin/tp_import_all_issues
```

## GitHub Project Requirements

Your GitHub Project (v2) must include:

### Required Project Fields
- **Status** (type: Single-select)
  - Used to map TargetProcess EntityState to the GitHub issue's project status. 
- **Estimate** (type: Number)
  - Used to sync TargetProcess "Effort" field.

### Required Status Values (Single-select Options)
Your "Status" field must include these option names (case-sensitive):
- Todo
- In progress
- Done
- Code review
- In testing
- Awaiting release

TP → GitHub status mapping:
| TP Status         | GitHub Status       |
|-------------------|--------------------|
| Open              | Todo               |
| Specified         | Todo               |
| Estimated         | Todo               |
| Planned           | Todo               |
| In Progress       | In progress        |
| In Testing        | In testing         |
| Awaiting Release  | Awaiting release   |
| Done              | Done               |
| Code Review       | Code review        |

If these values are missing, import will fail with an error listing available options.

### Assignee Mapping
If assigning GitHub users to issues, provide a mapping file referenced by `TP_TO_GITHUB_ASSIGNEE_MAPPING_FILE`:
```
user@company.com=ghusername
alice@corp.com=aliceGH
# Comments are supported
```
- All assignees to be mapped must appear in this file (TP email → GitHub username)
- No dedicated "Role" field is required in GitHub; mapping occurs via usernames.

### Estimate Field
Your project must include a numeric "Estimate" field named "Estimate". If ambiguous or missing, import will fail.

## Notes
- Attachments are uploaded as blobs in your repo under `tp_attachments/`
- Dry run and idempotency modes are strongly recommended for production use!
- All field option IDs for GitHub Projects v2 are looked up by name — you do not need to hardcode them.

---
PRs and suggestions are welcome!
