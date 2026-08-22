# shellcheck shell=bash
#
# Helpers shared by the scheduler backends in scripts/schedulers/.
#
# Source this after lib/config.sh and config::load. Backends are sourced by
# scripts/install-canvas-notion-automation, so they inherit REPO_DIR, the
# loaded configuration, and the resolved *_BIN values.

# The installer resolves binaries from the interactive PATH, but a scheduler
# runs the job with a PATH of its own choosing — the systemd user manager's,
# or cron's minimal default — which typically excludes ~/.local/bin, where
# codex often lives. Report the tools that would go missing at runtime so a
# backend can refuse to install rather than enabling a job that fails later.
#
# Usage: schedule::unreachable_bins <path-string> <command>...
# Fills SCHEDULE_UNREACHABLE with the command names that PATH cannot resolve.
schedule::unreachable_bins() {
  local search_path=$1
  shift

  SCHEDULE_UNREACHABLE=()
  local command_name
  for command_name in "$@"; do
    PATH="$search_path" command -v -- "$command_name" >/dev/null 2>&1 ||
      SCHEDULE_UNREACHABLE+=("$command_name")
  done
}

# Fail with the *_BIN overrides that would fix the unreachable tools.
# Usage: schedule::die_unreachable <what-has-the-path> <path-string> <command>...
schedule::die_unreachable() {
  local label=$1 search_path=$2
  shift 2

  local command_name override_lines="" override_line
  for command_name in "$@"; do
    printf -v override_line '  %s_BIN="%s"\n' \
      "$(printf '%s' "$command_name" | tr '[:lower:]' '[:upper:]')" \
      "$(command -v -- "$command_name")"
    override_lines+="$override_line"
  done

  config::die \
    "These tools are on your interactive PATH but not on $label," \
    "so the scheduled job would fail at runtime:" \
    "  $*" \
    "" \
    "That PATH is:" \
    "  $search_path" \
    "" \
    "Set absolute paths in config.local.sh, for example:" \
    "$override_lines" \
    "Nothing was installed."
}

# Directories holding the tools the run needs, for schedulers that must be
# handed an explicit PATH. Deduplicated, in resolution order, with the usual
# system directories last.
schedule::job_path() {
  local -a dirs=()
  local resolved candidate existing seen

  for resolved in "$CANVAS_BIN" "$JQ_BIN" "$CODEX_BIN" \
    /usr/local/bin/. /usr/bin/. /bin/.; do
    candidate="$(dirname -- "$resolved")"
    seen=false
    for existing in ${dirs+"${dirs[@]}"}; do
      [[ "$existing" == "$candidate" ]] && seen=true && break
    done
    "$seen" || dirs+=("$candidate")
  done

  local IFS=:
  printf '%s' "${dirs[*]}"
}

# Reject values that cannot appear safely in a generated schedule file.
# Control characters can inject directives into a crontab or a unit file.
schedule::reject_control_chars() {
  local label=$1 value=$2
  if [[ "$value" == *[[:cntrl:]]* ]]; then
    config::die "$label contains a control character and cannot be written safely."
  fi
}

# Validate CRON_SCHEDULE and split it into SCHEDULE_CRON_FIELDS.
# Accepts the five standard fields; named months and weekdays are not accepted
# because the launchd backend has to convert them to numbers.
schedule::parse_cron() {
  [[ -n "$CRON_SCHEDULE" ]] ||
    config::die \
      "CRON_SCHEDULE is empty in config.local.sh." \
      "The $AUTOMATION_SCHEDULER scheduler takes its schedule from it, for example:" \
      "  CRON_SCHEDULE=\"0 6,9,12,23 * * *\""

  schedule::reject_control_chars CRON_SCHEDULE "$CRON_SCHEDULE"

  # `read -a` rather than an unquoted expansion: the '*' fields would otherwise
  # be glob-expanded against the working directory.
  read -r -a SCHEDULE_CRON_FIELDS <<<"$CRON_SCHEDULE"
  [[ ${#SCHEDULE_CRON_FIELDS[@]} -eq 5 ]] ||
    config::die \
      "CRON_SCHEDULE must have exactly five fields (minute hour day month weekday)." \
      "Got ${#SCHEDULE_CRON_FIELDS[@]}: '$CRON_SCHEDULE'"

  local field
  for field in "${SCHEDULE_CRON_FIELDS[@]}"; do
    [[ "$field" =~ ^[0-9*,/-]+$ ]] ||
      config::die \
        "CRON_SCHEDULE field '$field' is not numeric cron syntax." \
        "Use numbers, '*', ',', '-', and '/' only — not names like MON or JAN."
  done
}
