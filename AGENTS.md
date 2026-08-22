# notion-workflow

A personal work-management system built in Notion, plus the automation that keeps it in sync with
Canvas LMS. The system itself lives in Notion; this repository holds its design docs and the Bash
and jq programs that drive the sync.

- [CONTEXT.md](CONTEXT.md) — the domain language. Use these words; the `_Avoid_` lines are terms the
  system deliberately rejects.
- [DESIGN.md](DESIGN.md) — the v1 spec: schema, invariants, homepage classification.
- [NOTION-SETUP.md](NOTION-SETUP.md) — how the Notion side is built, including both formula
  properties and the agent-assisted setup boundary.
- [AI-AGENT-GUIDE-TEMPLATE.md](AI-AGENT-GUIDE-TEMPLATE.md) — first-time setup only: seed the live
  runtime guide, replace every placeholder, then fetch the new guide before creating real work.
- [README.md](README.md) — setup and operation for a new installation.

## Local configuration

Workspace identifiers are not committed. When `config.local.sh` exists, read it for the live Notion
page and data-source IDs, the Canvas instance, and the timezone. It is created from
[config.example.sh](config.example.sh) and is the single source of truth for these values — do not
copy them into other files.

If `config.local.sh` is absent, this is an unconfigured clone. Follow [README.md](README.md) and
[NOTION-SETUP.md](NOTION-SETUP.md); do not guess identifiers or run the Canvas sync. Setup is
complete only after every required value has been copied into a mode-`0600` `config.local.sh` and
the Notion entities can be fetched through the configured identifiers.

`AUTOMATION_SCHEDULER` in the same file decides what starts the recurring sync — `systemd`, `cron`,
`launchd`, or `agent`. Treat it as the user's choice: install with
`scripts/install-canvas-notion-automation` (add `--scheduler NAME` only when the user asks for a
different backend), and never install a scheduler the configuration does not name. `agent` means the
user schedules the job elsewhere, including through your own scheduled tasks; in that mode the
installer only validates the configuration and prints the job definition, and registering it is a
change to the user's machine or account, so confirm before doing it.

If `AGENTS.local.md` exists, read it as well. It carries course-specific interpretation notes that
this repository deliberately does not publish.

## Notion

Reach the workspace through the Notion MCP tools (`notion-fetch`, `notion-search`,
`notion-update-page`, `notion-create-pages`).

For an existing installation, **read the AI Agent Guide page — `NOTION_AGENT_GUIDE_PAGE_ID` in
`config.local.sh` — before any mutation.** It is the authoritative rulebook for creating, editing,
and completing work, and it wins over DESIGN.md wherever the two disagree — DESIGN.md records the
intent, the guide records what is actually built.

During first-time setup there is no live guide yet. Keep every setup mutation inside the new home
page, create the AI Agent Guide before creating real Tasks or Stacks, then fetch that new guide and
use it as the authority for the rest of the installation. A connector-created set of views is not a
finished homepage: follow the canonical block order and completion checks in `NOTION-SETUP.md`.
Use the Notion UI to arrange or nest existing linked database blocks; do not attempt to move their
`<database>` tags with connector Markdown rewrites.

Keep `DESIGN.md` and the live AI Agent Guide synchronized. Every system-design change must update
both in the same operation and add a dated Changelog entry. Treat the change as incomplete if either
copy is stale; if a partial failure creates a temporary mismatch, the live guide remains authoritative
until the repository is reconciled.

Fetch the data source before writing to it — the guide's cached schema can lag the live one.

Two rules bite most often in practice:

- **Never invent a Due Date.** An Action or Deadline with no date belongs in Needs Setup, where the
  user resolves it. Ask, or leave the conflict visible.
- **Append, don't replace.** Task and Stack page bodies carry hand-written notes. Use
  `insert_content` or a targeted `update_content`; `replace_content` destroys them.

Keep Changelog dates as `YYYY-MM-DD` toggle headings ordered from most recent to least recent. Put
each day's details inside its toggle; insert a new date directly below `Daily changelog` and add
later same-day runs inside the existing date toggle.

Removing a `<page>` tag from a parent's content deletes that child page, so when reordering child
pages, leave the tag alone unless you intend the deletion.

Never delete or archive Notion content without the user's explicit permission for that exact
deletion. Unattended automation cannot obtain that permission: it must skip the destructive change
and append it to the Changelog's `Pending approval` section for a later user-directed agent.

The Canvas → Notion service is explicitly authorised to use Codex automatic approval review inside
the `workspace-write` sandbox, with a Notion-specific `Allow all actions` permission. This permits
safe headless writes only; it does not override the deletion rule above.

## Canvas

Use the `canvas-cli` skill. The instance is configured as `CANVAS_INSTANCE_NAME` in
`config.local.sh`; confirm auth with `canvas doctor`.

This project targets **student** accounts and invokes only student-readable endpoints. Account-level
and teacher commands return 403. Stick to reads plus the user's own submissions.

## Syncing a course into Notion

Each academic module is a **Stack** whose page body mirrors Canvas reference material, while
anything actionable becomes a **Task** related to that Stack.

For every current subject, sync the dedicated Canvas quizzes and announcements endpoints alongside
assignments, modules, pages, files, and discussions. Read announcement content for actionable work,
deadline changes, preparation instructions, and durable course references; do not treat an
announcement as title-only metadata.

Canvas is a weaker source than it looks, and these are the traps:

- **Due dates are often absent.** `canvas assignments list` can return nothing at all for a course,
  and quizzes are frequently undated. Real deadlines may live in a syllabus document rather than the
  API — so check the syllabus before concluding a course has no deadlines.
- **Pages are often wrappers around a `.docx`.** A weekly syllabus page body may be a single link.
  Download the file (`canvas files download <id>`) and unzip `word/document.xml` to read it.
  Splitting on `</w:tc>` and `</w:tr>` recovers table structure, which syllabus schedules depend on.
- **Tutorial timings are not in Canvas.** The section name is (`canvas api GET
  /api/v1/courses/<id>/sections`), but the day and time come from the user's timetable. Many
  deadlines are phrased relative to a tutorial, so ask for the day rather than guessing it.
- **Assessment weightings and submission mechanics live in the assignment prompt files**, not the
  gradebook. Download them.

When a date is derived rather than published, say so in the task body — name the syllabus wording it
came from — so a later sync can tell a derived date from an official one.

Course-specific findings belong in `AGENTS.local.md`, not here.
