# notion-workflow

A low-maintenance work-management system built in Notion, plus a scheduled job that keeps it in
sync with [Canvas LMS](https://www.instructure.com/canvas).

Everything actionable becomes a **Task** (an Action, a Deadline, or a Side Quest), optionally
grouped under a **Stack**. A Notion homepage classifies unfinished Tasks into Overdue, Due Today,
Closing In, Starting to Matter, Upcoming, and Side Quests so the question "what should I do now?"
has a visible answer. [DESIGN.md](DESIGN.md) is the full specification; [CONTEXT.md](CONTEXT.md)
defines the vocabulary.

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

**Linux with Bash 4+.** The scripts assume GNU userland behaviour and the runner uses `flock`.

Scheduling, though, is your choice. The unit of work is a single command —
`scripts/run-canvas-notion-sync` — and `AUTOMATION_SCHEDULER` in `config.local.sh` decides what
starts it:

| `AUTOMATION_SCHEDULER` | What the installer does | Schedule read from |
| --- | --- | --- |
| `systemd` | Installs and enables a systemd **user timer**. Catches up after downtime (`Persistent=true`). | `SYSTEMD_ON_CALENDAR` |
| `cron` | Maintains one marked block in your **user crontab**. Portable; no catch-up after downtime. | `CRON_SCHEDULE` |
| `launchd` | Installs a user **LaunchAgent** (macOS). Runs missed jobs after wake. | `CRON_SCHEDULE` |
| `agent` | Installs nothing. Validates the configuration and prints the job definition for an **external scheduler** — an agent's own scheduled task (Claude Code, Codex), CI, or you, by hand. | reports `CRON_SCHEDULE` |

Every backend installs the same job and refuses to install one that would fail at runtime, checking
that the tools it needs are reachable from the PATH that scheduler will actually use.

macOS therefore works for scheduling via `launchd`, `cron`, or `agent`, provided Bash 4+, `flock`,
and the other GNU tools are installed (`brew install bash flock coreutils binutils`) and reachable —
note that `#!/usr/bin/env bash` finds the system Bash 3.2 first unless Homebrew's `bin` precedes
`/bin` on your PATH. `launchd` and macOS `cron` schedule in the machine's local timezone rather than
`AUTOMATION_TIMEZONE`; the installer warns when the two differ.

## Prerequisites

| Tool | Purpose |
| --- | --- |
| `bash` 4+, `jq`, `unzip`, `flock` | Snapshot, diff, and text extraction |
| `strings` (binutils) | Best-effort text extraction from PDFs |
| [`canvas`](https://github.com/jjuanrivvera/canvas-cli) | All Canvas reads |
| [`codex`](https://developers.openai.com/codex/cli) | Runs the sync agent |
| a scheduler | `systemd`, `cron`, `launchd`, or one you drive yourself — see [Supported platform](#supported-platform) |

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

**7. Install the schedule.** Set `AUTOMATION_SCHEDULER` and the matching schedule setting in
`config.local.sh` first, then:

```bash
scripts/install-canvas-notion-automation
```

It validates the whole configuration, renders whatever the chosen scheduler needs, verifies it, and
installs it — printing the run, status, log, and removal commands for that scheduler. To try a
different backend without editing the config:

```bash
scripts/install-canvas-notion-automation --scheduler cron
```

With `AUTOMATION_SCHEDULER="agent"` nothing is installed: the command prints the command, working
directory, schedule, timezone, and PATH for an agent or another scheduler to register, along with
what that scheduler needs to know about retries and timeouts.

## Operation

Whatever the scheduler, a sync can always be run directly:

```bash
scripts/run-canvas-notion-sync
```

Under `systemd`, run one immediately and check the schedule and recent logs with:

```bash
systemctl --user start canvas-notion-sync.service
```

```bash
systemctl --user status canvas-notion-sync.timer
```

```bash
journalctl --user -u canvas-notion-sync.service -n 100
```

The `cron` and `launchd` backends write their output to `cron.log` and `launchd.log` in
`CANVAS_SYNC_STATE_DIR`; the installer prints their status and removal commands when it finishes.

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

**"…not on the systemd user manager's PATH"**, or the same complaint about a crontab or LaunchAgent
PATH — schedulers run jobs with a PATH of their own, typically excluding `~/.local/bin`, where
`codex` often lives. The installer checks this up front and refuses to install rather than enabling
a job that would fail at runtime; set an absolute `CODEX_BIN` in `config.local.sh` as the error
instructs.

**"launchd cannot express the … field"** — `StartCalendarInterval` matches fixed values, so
`CRON_SCHEDULE` cannot use ranges or steps under `launchd`. Write the values out: `0 6,9,12,23 * * *`
rather than `0 6-23/3 * * *`.

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
