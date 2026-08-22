# shellcheck shell=bash
#
# cron backend. Maintains one marked block in the user's crontab; everything
# outside the markers is preserved byte for byte.

config::need_bins crontab

readonly BLOCK_BEGIN="# >>> notion-workflow canvas-notion-sync >>>"
readonly BLOCK_END="# <<< notion-workflow canvas-notion-sync <<<"

schedule::parse_cron
schedule::reject_control_chars "The repository path" "$REPO_DIR"

# cron runs jobs with a minimal PATH — often just /usr/bin:/bin — so the block
# sets one covering the tools this job resolved at install time.
job_path="$(schedule::job_path)"
schedule::unreachable_bins "$job_path" ${PATH_RESOLVED_BINS+"${PATH_RESOLVED_BINS[@]}"}
if [[ ${#SCHEDULE_UNREACHABLE[@]} -gt 0 ]]; then
  schedule::die_unreachable "the PATH this crontab entry would set" \
    "$job_path" "${SCHEDULE_UNREACHABLE[@]}"
fi

# cron hands the command to /bin/sh, so paths containing spaces need quoting,
# and `%` — which cron reads as a newline separator — needs escaping afterwards.
shell_quote() {
  local value=${1//\'/\'\\\'\'}
  printf "'%s'" "$value"
}

runner="$REPO_DIR/scripts/run-canvas-notion-sync"
log_file="$CANVAS_SYNC_STATE_DIR/cron.log"
command_line="$(shell_quote "$runner") >>$(shell_quote "$log_file") 2>&1"
command_line="${command_line//\%/\\%}"

# CRON_TZ is a Vixie-cron extension. macOS cron ignores it and would silently
# run on system local time instead of AUTOMATION_TIMEZONE.
tz_line="CRON_TZ=$AUTOMATION_TIMEZONE"
if [[ "$(uname -s)" == "Darwin" ]]; then
  tz_line="# CRON_TZ is not supported by this cron; the schedule below is system local time."
  printf 'Warning: macOS cron has no CRON_TZ. The schedule runs in system local\n' >&2
  printf '         time, not %s. Use the launchd scheduler for a\n' "$AUTOMATION_TIMEZONE" >&2
  printf '         calendar-driven job that also survives sleep.\n' >&2
fi

block="$BLOCK_BEGIN
# Managed by scripts/install-canvas-notion-automation. Edit config.local.sh and
# re-run it rather than editing these lines.
PATH=$job_path
$tz_line
$CRON_SCHEDULE $command_line
$BLOCK_END"

existing="$(crontab -l 2>/dev/null || true)"

# Drop any previous block, then append the current one.
filtered="$(
  printf '%s\n' "$existing" |
    awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" '
      $0 == begin { skipping = 1; next }
      $0 == end   { skipping = 0; next }
      !skipping
    '
)"

# Command substitution has already stripped the trailing newlines the awk
# filter leaves behind, so repeated installs do not accumulate blank lines.

if [[ -n "$filtered" ]]; then
  printf '%s\n\n%s\n' "$filtered" "$block" | crontab -
else
  printf '%s\n' "$block" | crontab -
fi

mkdir -p -- "$CANVAS_SYNC_STATE_DIR"
chmod 700 "$CANVAS_SYNC_STATE_DIR"

printf 'Installed the cron entry (%s).\n' "$CRON_SCHEDULE"
printf 'Run now:    %s\n' "$runner"
printf 'Schedule:   crontab -l\n'
printf 'Logs:       tail -n 100 %s\n' "$log_file"
printf 'Remove:     crontab -e, then delete the marked block.\n'
