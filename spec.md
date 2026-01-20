# tp-to-github — Specification

## Overview

**tp-to-github** is a Ruby command-line tool that migrates hierarchical work items from a TargetProcess (TP) instance (via API) into a private GitHub repository as GitHub issues, preserving work item relationships as GitHub sub-issues. It also attaches all relevant metadata, tasks (as checklists), and uploaded file attachments.

The tool is intended for **one-way, idempotent import**—it does not erase, update, or re-sync items already imported.

---

## Supported Entities & Hierarchy

The TP → GitHub import maps as follows:

```
TargetProcess Project
└── Epic
    └── Feature
        └── UserStory (Story)
            └── Tasks (embedded as checklist)
```

Each of these entities (except Tasks) becomes a distinct GitHub Issue. Tasks for a UserStory become a checklist in that Story’s issue body.

- **Projects**: Imported as top-level issues.
- **Epics**: Sub-issues of their Project issue.
- **Features**: Sub-issues of their Epic issue.
- **UserStories**: Sub-issues of their Feature issue.
- **Tasks**: Markdown checklist in the UserStory issue only.
- **Attachments**: Uploaded to the repository; linked in an “Attachments” section in each issue.

---

## API and Authentication

- **TargetProcess**:
    - TP API v1 (GET requests only)
    - Auth: HTTP Basic (from environment)
- **GitHub**:
    - REST API (using a personal access token)
    - Private repository only (for attachment uploads)
    - Sub-issue APIs (for hierarchy)

---

## Filtering

- Only work items for a given team (`TP_TEAM_ID`, default: `35411`)
- All API listing endpoints exclude items where `EntityState.Name = 'Done'`.
- Only imports one story (and its parent chain) per run (script expects `TP_STORY_ID`).

---

## Fields and Formatting

**Imported issue fields:**
- **Title**: TP entity’s `Name` (no prefixes)
- **Body**:
    - TP `Description` (converted from HTML to Markdown unless it starts with `<!--markdown-->`, in which case use as-is)
    - “Tasks” checklist (for UserStory/Story issues only, if tasks exist)
    - “Attachments” section (see below)
    - Import note:  
      `_Imported from TargetProcess: [#<id>](<TP_BASE_URL>/entity/<id>)_`
    - Stable idempotency marker:  
      `<!--tp:<Type>:<Id>-->` (always at the very end)

**Tasks implementation:**
- Tasks are not issues, but markdown checklists in the UserStory body:
    - Section Title: `### Tasks`
    - Lines: `- [ ] Task name`
    - Placed after description, before attachments/import note

**Attachments:**
- Every entity type (Project, Epic, Feature, UserStory) supports TP attachments.
- All attachments for an issue are uploaded into the GitHub repository at:
    ```
    tp_attachments/<TpType>/<TpId>/<AttachmentId><ext>
    ```
    - Filename is always the TP attachment’s numeric `Id` plus its file extension (**not** the original filename).
- The “### Attachments” section lists all as `[original-filename](blob-url)`.
- Blob URLs are constructed as:
    ```
    https://github.com/<OWNER>/<REPO>/blob/master/tp_attachments/<TpType>/<TpId>/<AttachmentId><ext>
    ```

**Idempotency:**
- By default, the tool checks for an existing imported item for each TP entity
  by looking for the body marker (`<!--tp:Type:Id-->`) using GitHub search.
- This is controlled by the `IDEMPOTENT` environment variable:
    - `IDEMPOTENT=1` (default): skip creating a new issue for an imported marker
    - `IDEMPOTENT=0`: always create a new GitHub issue (never reuse, for testing)

**Mute Behavior:**
- Issues created during import are auto-muted for the authenticated user (via `/subscription` API).

---

## Command-Line Usage

**Main entry point**: `bin/tp_import_one_issue`

**Required environment:**
- `TP_BASE_URL`, `TP_USERNAME`, `TP_PASSWORD`
- `GITHUB_REPO`, `GITHUB_ACCESS_TOKEN`
- `TP_STORY_ID`
- (optional) `TP_TEAM_ID`
- (optional) `DRY_RUN`
- (optional) `IDEMPOTENT`

**Behavior:**
1. Fetch specified Story by ID, its chain of Feature → Epic → Project.
2. For each, fetch attachments and upload them to GitHub (unless `DRY_RUN=1`).
3. For each, build appropriate issue body using name, markdown-converted description, tasks, attachments, note, and marker.
4. For each, look for an existing imported issue (unless `IDEMPOTENT=0`), otherwise create.
5. Link up issues using sub-issue APIs, forming a hierarchy.
6. Output a JSON plan if `DRY_RUN=1`—no GitHub or TP content is created or modified.
7. Any newly created issues are muted for notifications.
8. Errors downloading/muting attachments or issues are soft-fail (DO NOT halt).

---

## Attachments: TP → GitHub Implementation

- Uses `/api/v1/Attachments` with `where=General.Id eq ... and General.EntityType.Name eq 'UserStory'` (etc.) to find attachments for each entity.
- “Raw bytes” download:  
  `/api/v1/Attachments/<id>?select=UniqueFileName` to get the blob name, then `/attachment.aspx?filename=...`
- Upload to GitHub Contents API, skipping if the file already exists at the target path.

---

## Testing/Idempotency Switching

- All major actions are covered by RSpec and WebMock tests.
- Use `DRY_RUN=1` for plan output only (off for actual API calls).
- Use `IDEMPOTENT=0` to force new issue creation for each import (useful for tests).

---

## Design Notes

- All code is in `lib/tp_to_github/`
- One-shot executable in `bin/`
- All authentication and behavior is controlled by environment variables.
- The tool is team-centric and does **not** sync comments/updates back from GitHub to TP.
- Any failure in uploading/muting attachments or issues *does not* prevent the rest of the import from proceeding.

---
