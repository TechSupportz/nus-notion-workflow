# shellcheck shell=bash
#
# systemd user timer backend. Renders the unit templates in automation/ from
# config.local.sh, verifies them, and enables the timer.
#
# Sourced by scripts/install-canvas-notion-automation with the configuration
# already loaded and PATH_RESOLVED_BINS already populated.

# A host without systemd is a scheduler choice, not a missing dependency.
command -v systemctl >/dev/null 2>&1 ||
  config::die \
    "This host has no systemctl, so the systemd scheduler cannot be used." \
    "" \
    "Set AUTOMATION_SCHEDULER in config.local.sh to one of:" \
    "  cron      an entry in your user crontab" \
    "  launchd   a user LaunchAgent (macOS)" \
    "  agent     install nothing; print the job for an external scheduler"

config::need_bins systemctl systemd-analyze

readonly UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
readonly GENERATED_DIR="$REPO_DIR/automation"

service_path="$(systemctl --user show-environment 2>/dev/null | sed -n 's/^PATH=//p' || true)"
if [[ -n "$service_path" && ${#PATH_RESOLVED_BINS[@]} -gt 0 ]]; then
  schedule::unreachable_bins "$service_path" "${PATH_RESOLVED_BINS[@]}"
  if [[ ${#SCHEDULE_UNREACHABLE[@]} -gt 0 ]]; then
    schedule::die_unreachable \
      "the systemd user manager's PATH" "$service_path" "${SCHEDULE_UNREACHABLE[@]}"
  fi
fi

[[ -n "$SYSTEMD_ON_CALENDAR" ]] ||
  config::die \
    "SYSTEMD_ON_CALENDAR is empty in config.local.sh." \
    "The systemd scheduler takes its schedule from it, for example:" \
    "  SYSTEMD_ON_CALENDAR=\"*-*-* 06,09,12,23:00:00\""

# systemd applies the timezone as a suffix on the calendar expression, so
# AUTOMATION_TIMEZONE stays the single source of truth for both the schedule
# and the changelog dates the model writes.
readonly ON_CALENDAR="$SYSTEMD_ON_CALENDAR $AUTOMATION_TIMEZONE"

# Reject values that cannot appear safely in a quoted unit-file value. Control
# characters can inject directives, while double quotes and dollar signs can
# break quoting or trigger systemd expansion.
reject_unit_metacharacters() {
  local label=$1 value=$2
  schedule::reject_control_chars "$label" "$value"
  if [[ "$value" == *'"'* || "$value" == *'$'* ]]; then
    config::die \
      "$label contains a double quote or dollar sign and cannot be written" \
      "safely into a unit file."
  fi
}

reject_unit_metacharacters "The repository path" "$REPO_DIR"
reject_unit_metacharacters "SYSTEMD_ON_CALENDAR" "$ON_CALENDAR"

# `%` introduces a systemd specifier; escape it so paths survive literally.
# The `%` in the pattern must be backslash-escaped: bash reads a leading `%` in
# a substitution pattern as the match-at-end anchor, which would append `%%`
# to every value instead of escaping the percent signs inside it.
escape_specifiers() {
  printf '%s' "${1//\%/%%}"
}

# Render with bash parameter substitution rather than sed: no delimiter, no
# ampersand, and no backslash has special meaning in the replacement.
render_unit() {
  local template=$1 output=$2 content
  content="$(<"$template")"
  content="${content//@REPO_DIR@/$(escape_specifiers "$REPO_DIR")}"
  content="${content//@ON_CALENDAR@/$(escape_specifiers "$ON_CALENDAR")}"
  printf '%s\n' "$content" >"$output"
}

systemd-analyze calendar -- "$ON_CALENDAR" >/dev/null 2>&1 ||
  config::die \
    "SYSTEMD_ON_CALENDAR is not a schedule systemd accepts:" \
    "  '$ON_CALENDAR'" \
    "Check it with: systemd-analyze calendar '$ON_CALENDAR'"

render_unit \
  "$GENERATED_DIR/canvas-notion-sync.service.in" \
  "$GENERATED_DIR/canvas-notion-sync.service"
render_unit \
  "$GENERATED_DIR/canvas-notion-sync.timer.in" \
  "$GENERATED_DIR/canvas-notion-sync.timer"

# Verify before touching the installed units, so a bad render never replaces a
# working installation.
if ! systemd-analyze verify \
  "$GENERATED_DIR/canvas-notion-sync.service" \
  "$GENERATED_DIR/canvas-notion-sync.timer"; then
  config::die \
    "The generated units failed systemd-analyze verify; nothing was installed." \
    "Inspect them in $GENERATED_DIR/."
fi

mkdir -p -- "$UNIT_DIR"
install -m 0644 \
  "$GENERATED_DIR/canvas-notion-sync.service" \
  "$UNIT_DIR/canvas-notion-sync.service"
install -m 0644 \
  "$GENERATED_DIR/canvas-notion-sync.timer" \
  "$UNIT_DIR/canvas-notion-sync.timer"

systemctl --user daemon-reload
systemctl --user enable --now canvas-notion-sync.timer

printf 'Installed and enabled canvas-notion-sync.timer (%s).\n' "$ON_CALENDAR"
printf 'Run now:    systemctl --user start canvas-notion-sync.service\n'
printf 'Schedule:   systemctl --user status canvas-notion-sync.timer\n'
printf 'Logs:       journalctl --user -u canvas-notion-sync.service -n 100\n'
