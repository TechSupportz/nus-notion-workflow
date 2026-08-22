# shellcheck shell=bash
#
# No-op backend for installations scheduled by something outside this
# repository — an agent's own scheduled-task feature (Claude Code, Codex),
# a CI cron, or a human running the sync by hand.
#
# It changes nothing on the host. It validates the configuration exactly as
# the other backends do and then prints the job definition the external
# scheduler needs.

readonly runner="$REPO_DIR/scripts/run-canvas-notion-sync"
job_path="$(schedule::job_path)"

schedule_line="CRON_SCHEDULE is not set in config.local.sh"
[[ -n "$CRON_SCHEDULE" ]] && schedule_line="$CRON_SCHEDULE (cron syntax)"

cat <<SUMMARY
Configuration checked. Nothing was installed: AUTOMATION_SCHEDULER is 'agent',
so scheduling is handled outside this repository.

Register this job with whichever scheduler you use.

  Command:    $runner
  Directory:  $REPO_DIR
  Schedule:   $schedule_line
  Timezone:   $AUTOMATION_TIMEZONE
  PATH:       $job_path

Notes for whoever registers it:

  * The runner is idempotent and self-limiting. It takes a lock, exits without
    starting a model when Canvas has not changed, and does not advance its
    baseline on a failed or partial run, so a retry repeats the same diff
    rather than skipping it.
  * Give it up to 45 minutes; a diff-triggered run drives a reasoning model.
  * It needs canvas, jq, codex, flock, unzip, and strings on PATH, and the
    Notion Codex plugin already authorized — a headless run cannot complete an
    authorization prompt.
  * Output is plain stdout/stderr; capture it wherever your scheduler keeps
    logs. Exit 0 means the run completed, including the no-change case.
  * An agent scheduling this on its own timer must not treat a failed run as a
    reason to re-run immediately; the next scheduled run retries the same diff.

Run it once now to confirm the setup:

  $runner
SUMMARY
