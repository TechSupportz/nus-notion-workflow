# Canvas → Notion automation

A systemd user timer checks the current academic-term Canvas courses on the schedule set by
`SYSTEMD_ON_CALENDAR` and `AUTOMATION_TIMEZONE` in `config.local.sh`.

`scripts/canvas-snapshot` performs read-only Canvas CLI calls and normalizes assignments, quizzes,
announcements, modules, pages, files, and discussions for every current subject. Announcements are
inspected for actionable work, deadline changes, preparation instructions, and durable course
references—not just recorded as titles. `scripts/run-canvas-notion-sync` compares the result with the last
successful snapshot. It exits without starting a model when nothing changed.
When Canvas changed, it runs the configured `CODEX_MODEL` with high reasoning and
asks it to apply only the diff through the connected Notion tools.

Runtime values — the change-bundle path, the Notion page and data-source IDs, and the timezone —
reach the model as a JSON context block prepended to `canvas-notion-sync-prompt.md`. The prompt
itself stays static; nothing is templated into it.

Every diff-triggered run also writes a dated entry to the Notion Changelog page
(`NOTION_CHANGELOG_PAGE_ID`). Dates are toggle headings ordered newest-first, with the run details
nested inside the matching date toggle. The automation never deletes or archives Notion content. Changes that
would require deletion are skipped and added as unchecked items under `Pending approval`, with the
target, reason, and consequence for a user-directed agent to handle later.

The user has explicitly authorised Codex automatic approval review for this headless service. It
remains inside the `workspace-write` sandbox; the Notion app has its own `Allow all actions`
override so safe synchronization writes can complete without an interactive prompt. Destructive
Notion actions remain forbidden and must be deferred to `Pending approval`.

New or modified Canvas files are downloaded only after a diff detects them.
Office documents are text-extracted for the agent, including table-aware DOCX
extraction for syllabus schedules. This avoids repeatedly downloading every
course file. A locked or otherwise unavailable file is retained in the change bundle with an
explanatory artifact note instead of failing the entire run.

Runtime state lives in `CANVAS_SYNC_STATE_DIR`, by default
`~/.local/state/notion-workflow-canvas-sync/`, created mode `0700` because it holds downloaded
coursework and extracted text. A failed or partial Notion run or an unverified Changelog write does
not advance the baseline, so the next timer run retries idempotently.

The official Notion Codex plugin must be installed and connected for headless
runs; the installer does not alter its permissions.

Useful commands:

```bash
systemctl --user status canvas-notion-sync.timer
```

```bash
systemctl --user start canvas-notion-sync.service
```

```bash
journalctl --user -u canvas-notion-sync.service -n 100
```

Render the unit templates from `config.local.sh`, verify them, and install:

```bash
scripts/install-canvas-notion-automation
```

To establish or deliberately refresh the Canvas baseline without changing
Notion:

```bash
scripts/run-canvas-notion-sync --baseline-only
```
