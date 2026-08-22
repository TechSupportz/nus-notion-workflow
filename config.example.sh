# Copy to config.local.sh and fill in. config.local.sh is gitignored.
#
#   cp config.example.sh config.local.sh && chmod 600 config.local.sh
#
# This file is sourced by Bash. It is NOT a dotenv file: values must be quoted
# using shell rules, and anything you write here executes.

# --- Notion -------------------------------------------------------------
# 32-character page IDs, as they appear in an app.notion.com/p/<id> URL.
# The data-source values are the `collection://<uuid>` URIs the Notion
# connector reports; fetch a database once and copy them from the response.

NOTION_HOME_PAGE_ID=""
NOTION_AGENT_GUIDE_PAGE_ID=""
NOTION_CHANGELOG_PAGE_ID=""
NOTION_GROUNDING_FACTS_PAGE_ID=""
NOTION_TASKS_DATABASE_ID=""
NOTION_TASKS_DATA_SOURCE_URI=""
NOTION_STACKS_DATABASE_ID=""
NOTION_STACKS_DATA_SOURCE_URI=""

# --- Grounding Facts sources --------------------------------------------
# The two links the Grounding Facts page is derived from. They are personal
# (the timetable URL encodes your exact class selections), so they live here
# rather than in the committed documentation. Whoever rebuilds the page at the
# start of a semester reads them from here.

# Your institution's academic calendar for the current academic year, e.g.
#   "https://university.example.edu/registrar/calendar/ay2026-2027.pdf"
GROUNDING_CALENDAR_URL=""

# A timetable share URL carrying your enrolled modules and chosen classes, e.g.
#   "https://nusmods.com/timetable/sem-1/share?CS1101S=LEC:1,TUT:07"
GROUNDING_TIMETABLE_URL=""

# --- Canvas -------------------------------------------------------------
# Named instance configured via `canvas auth token set <name>` or
# `canvas auth login --instance <url>`. Leave empty to fall back to the
# Canvas CLI's own default profile, or to CANVAS_URL/CANVAS_TOKEN.
CANVAS_INSTANCE_NAME=""

# Course selection. Set at least one of the following. If both are set, the
# explicit course IDs take precedence.
#
# A regular expression matched case-insensitively against the Canvas *term
# name* to pick the current academic term. This varies by institution:
#   semester-based institutions:  "semester"
#   US universities:  "fall|spring|summer"
# Inspect your own term names first with:
#   canvas courses list --enrollment-type student --include term -o json
CANVAS_TERM_NAME_REGEX=""

# Or pin an explicit comma-separated list of course IDs, which overrides the
# term regex entirely.
CANVAS_SYNC_COURSE_IDS=""

# --- Locale and schedule ------------------------------------------------
# IANA timezone used for changelog dates and all Due Date boundaries.
AUTOMATION_TIMEZONE="Etc/UTC"

# How the recurring sync is scheduled. The unit of work is always
# scripts/run-canvas-notion-sync; this only chooses what starts it.
#
#   systemd   systemd user timer (Linux). Catches up after downtime.
#   cron      an entry in your user crontab. Portable; no catch-up.
#   launchd   a user LaunchAgent (macOS). Runs missed jobs after wake.
#   agent     install nothing. `scripts/install-canvas-notion-automation`
#             validates the configuration and prints the job definition for
#             an external scheduler — an agent's own scheduled task (Claude
#             Code, Codex), CI, or a human running it by hand.
#
# Override for one run with: scripts/install-canvas-notion-automation --scheduler NAME
AUTOMATION_SCHEDULER="systemd"

# Schedule for AUTOMATION_SCHEDULER="systemd". Do not append a timezone — the
# installer adds AUTOMATION_TIMEZONE automatically, so it is configured in
# exactly one place. Validate with:
#   systemd-analyze calendar "*-*-* 06,09,12,23:00:00 Etc/UTC"
SYSTEMD_ON_CALENDAR="*-*-* 06,09,12,23:00:00"

# Schedule for AUTOMATION_SCHEDULER="cron" and "launchd", in five-field cron
# syntax, and the schedule reported by the "agent" scheduler. Use numbers only:
# launchd cannot express ranges or steps, so write values out as lists.
#
# cron on Linux honours the timezone via CRON_TZ; macOS cron and launchd
# schedule in system local time, which the installer warns about when it
# differs from AUTOMATION_TIMEZONE.
CRON_SCHEDULE="0 6,9,12,23 * * *"

# --- Binaries and model -------------------------------------------------
# Leave blank to resolve from PATH. Set an absolute path only when a tool is
# installed somewhere unusual.
CANVAS_BIN=""
JQ_BIN=""
CODEX_BIN=""

# Model used for the unattended sync. It must be available to the installed
# Codex CLI and the account running the systemd user service.
CODEX_MODEL="gpt-5.6-luna"

# --- Advanced (optional) ------------------------------------------------
# Runtime state: baseline snapshot, change bundles, downloaded course files.
# Contains private coursework; created with mode 0700.
# CANVAS_SYNC_STATE_DIR="$HOME/.local/state/notion-workflow-canvas-sync"

# Skip downloading Canvas files larger than this (bytes). Default 15 MiB.
# CANVAS_SYNC_MAX_FILE_BYTES="15728640"

# Truncate extracted text at this many bytes. Default 500 kB.
# CANVAS_SYNC_MAX_EXTRACTED_BYTES="500000"
