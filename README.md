# notion-workflow

A low-maintenance work-management system built in Notion, plus a systemd timer that keeps it in
sync with [Canvas LMS](https://www.instructure.com/canvas).

Everything actionable becomes a **Task** (an Action, a Deadline, or a Side Quest), optionally
grouped under a **Stack**. A Notion homepage classifies unfinished Tasks into Overdue, Due Today,
Starting to Matter, Upcoming, and Side Quests so the question "what should I do now?" has a visible
answer. [DESIGN.md](DESIGN.md) is the full specification; [CONTEXT.md](CONTEXT.md) defines the
vocabulary.

On the configured schedule — four times a day by default — the automation snapshots your Canvas
courses, diffs against the previous snapshot,
and — only when something actually changed — hands the diff to a Codex agent that applies it to
Notion through the official Notion connector. It never deletes anything: changes that would require
a deletion are queued for you under a `Pending approval` heading in a Notion changelog.

## What this repository does and does not give you

It gives you the **automation**, the **specification** ([DESIGN.md](DESIGN.md)), and a step-by-step
**build procedure** for the Notion side ([NOTION-SETUP.md](NOTION-SETUP.md)) including copyable
`Homepage Section` and `Show in Completed` formulas.

There is no standalone bootstrap script. You can follow the procedure in the Notion UI or ask a
Codex session with the connected Notion plugin to create the home page, databases, formulas, and
views. Database locking, the one-page relation limit, final layout, and visual verification still
require the Notion UI. Connector-created views append to the page; the build is not complete until
they match the canonical block order and pass the visual checks in
[NOTION-SETUP.md § 5](NOTION-SETUP.md#5-build-the-homepage). Budget 30–60 minutes for a new
installation.

The intended task presentation is not a set of Tables: Today and Upcoming use Medium Compact
Gallery cards, Completed uses a Gallery, and Side Quests and Needs Setup use Lists. The connector
can create those view types, but the Compact card controls in Notion still require the UI.

## Supported platform

**Linux with Bash and systemd user services.** The scheduler is a systemd user timer and the runner
uses `flock`.

The scripts use GNU userland behaviour and may run manually on other Unix-like systems when
compatible GNU tools are installed. There is no launchd equivalent for macOS scheduling and none
is planned.

## Prerequisites

| Tool | Purpose |
| --- | --- |
| `bash` 4+, `jq`, `unzip`, `flock` | Snapshot, diff, and text extraction |
| `strings` (binutils) | Best-effort text extraction from PDFs |
| [`canvas`](https://github.com/jjuanrivvera/canvas-cli) | All Canvas reads |
| [`codex`](https://developers.openai.com/codex/cli) | Runs the sync agent |
| `systemd` | Scheduling |

The official **Notion plugin for Codex** must be installed and connected, because the sync agent
reaches Notion through it. Verify it works in an interactive Codex session before enabling the
timer — headless runs cannot complete an authorization prompt.

## Setup

**1. Authenticate Canvas.** A student account is enough; the automation only calls student-readable
endpoints.

```bash
canvas auth login --instance https://canvas.example.edu
```

Confirm with `canvas doctor`.

**2. Build the Notion system.** Follow [NOTION-SETUP.md](NOTION-SETUP.md), which covers the Tasks
and Stacks databases, their properties and relation, both formula properties, the homepage views,
the AI Agent Guide page, and the append-only Changelog page. The guide marks the steps that still
require the Notion UI when an agent assists with setup. Do not continue to configuration until the
homepage passes the fetched-structure and visual completion checks in step 5.

**3. Collect the identifiers**, as described in
[NOTION-SETUP.md § 7](NOTION-SETUP.md#7-collect-the-identifiers). Page and database IDs are the
32 hex characters in a Notion URL; the `collection://<uuid>` data-source URIs come from fetching
each database once through the connector.

**4. Configure.**

```bash
cp config.example.sh config.local.sh && chmod 600 config.local.sh
```

Fill it in. `config.local.sh` is gitignored and is the single source of truth for every identifier —
nothing else in the repository hardcodes them. The one setting worth reading twice is course
selection: set either `CANVAS_TERM_NAME_REGEX` (matched against your institution's Canvas *term
name*, e.g. `semester` or `fall|spring`) or an explicit `CANVAS_SYNC_COURSE_IDS`. Inspect your own
term names first:

```bash
canvas courses list --enrollment-type student --include term -o json
```

**5. Optionally add course notes.** Copy `AGENTS.local.example.md` to `AGENTS.local.md` for
course-specific context agents should know but the repository should not publish.

**6. Establish a baseline.** This records the current state of Canvas without touching Notion, so
the first real run syncs only genuine changes rather than your entire course history:

```bash
scripts/run-canvas-notion-sync --baseline-only
```

**7. Install the timer.** This renders the unit templates from your config, validates them with
`systemd-analyze verify`, and enables the timer:

```bash
scripts/install-canvas-notion-automation
```

## Operation

Run a sync immediately:

```bash
systemctl --user start canvas-notion-sync.service
```

Check schedule and recent logs:

```bash
systemctl --user status canvas-notion-sync.timer
```

```bash
journalctl --user -u canvas-notion-sync.service -n 100
```

A run that fails, partially completes, or cannot verify its changelog entry **does not advance the
baseline**, so the next run retries the same diff idempotently.

See [automation/README.md](automation/README.md) for the internals.

## Troubleshooting

**"No Canvas courses matched …"** — the guard that refuses to overwrite a good snapshot with an
empty one. The error lists every active enrolment with its term name; adjust
`CANVAS_TERM_NAME_REGEX` or `CANVAS_SYNC_COURSE_IDS` to match.

**"Required tools are not installed or not on PATH"** — install the named tool. Only `canvas`, `jq`,
and `codex` have config overrides (`CANVAS_BIN`, `JQ_BIN`, `CODEX_BIN`); everything else must be on
`PATH`.

**"…not on the systemd user manager's PATH"** — the service does not set `PATH` explicitly, and the
systemd user manager typically excludes `~/.local/bin`, where `codex` often lives. The installer
checks this up front and refuses to install rather than enabling a timer that would fail at runtime;
set an absolute `CODEX_BIN` in `config.local.sh` as the error instructs.

**The agent reports `error` every run** — check that the Notion Codex plugin is still connected. Its
authorization cannot be renewed from a headless run.

## Privacy

Runtime state in `~/.local/state/notion-workflow-canvas-sync/` contains your assignment
descriptions, submission status, downloaded course files, and extracted text. It is created mode
`0700`; keep `config.local.sh` at `0600`.

Canvas content is treated as untrusted input. The sync prompt instructs the agent never to follow
instructions embedded in assignment text, page bodies, discussions, or filenames.

## Licence

MIT — see [LICENSE](LICENSE), which also covers the vendored `canvas-cli` skill in `.agents/`.
