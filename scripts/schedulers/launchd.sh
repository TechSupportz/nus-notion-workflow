# shellcheck shell=bash
#
# launchd backend for macOS. Renders a LaunchAgent from CRON_SCHEDULE and
# bootstraps it into the user's GUI domain.
#
# launchd runs missed calendar jobs once the machine wakes, which is the
# closest equivalent to the systemd timer's Persistent=true.

config::need_bins launchctl plutil

readonly LABEL="com.notion-workflow.canvas-notion-sync"
readonly AGENT_DIR="$HOME/Library/LaunchAgents"
readonly PLIST="$AGENT_DIR/$LABEL.plist"

schedule::parse_cron

job_path="$(schedule::job_path)"
schedule::unreachable_bins "$job_path" ${PATH_RESOLVED_BINS+"${PATH_RESOLVED_BINS[@]}"}
if [[ ${#SCHEDULE_UNREACHABLE[@]} -gt 0 ]]; then
  schedule::die_unreachable "the PATH this LaunchAgent would set" \
    "$job_path" "${SCHEDULE_UNREACHABLE[@]}"
fi

# StartCalendarInterval is a fixed set of matched fields, so ranges and steps
# have no representation; only '*' and explicit lists convert cleanly.
# An unconstrained field becomes the sentinel `_`, which contributes no key to
# the dict below and so matches every value.
expand_field() {
  local field=$1 name=$2
  if [[ "$field" == "*" ]]; then
    printf '_'
    return 0
  fi
  [[ "$field" == *[/-]* ]] &&
    config::die \
      "launchd cannot express the $name field '$field' from CRON_SCHEDULE." \
      "StartCalendarInterval matches fixed values, so ranges ('-') and steps" \
      "('/') are unsupported. Write the values out, for example '6,9,12,23'."
  printf '%s' "${field//,/ }"
}

minutes="$(expand_field "${SCHEDULE_CRON_FIELDS[0]}" minute)"
hours="$(expand_field "${SCHEDULE_CRON_FIELDS[1]}" hour)"
days="$(expand_field "${SCHEDULE_CRON_FIELDS[2]}" "day of month")"
months="$(expand_field "${SCHEDULE_CRON_FIELDS[3]}" month)"
weekdays="$(expand_field "${SCHEDULE_CRON_FIELDS[4]}" weekday)"

# One dict per combination of the constrained fields; an unconstrained field
# contributes no key, which launchd reads as "every value".
intervals=""
emit_key() {
  local key=$1 value=$2
  [[ "$value" == "_" ]] && return 0
  intervals+=$'\t\t\t<key>'"$key"$'</key><integer>'"$value"$'</integer>\n'
}

emit_interval() {
  intervals+=$'\t\t<dict>\n'
  emit_key Minute "$1"
  emit_key Hour "$2"
  emit_key Day "$3"
  emit_key Month "$4"
  emit_key Weekday "$5"
  intervals+=$'\t\t</dict>\n'
}

# Values are digits and the `_` sentinel, but disable globbing anyway: these
# expansions are deliberately unquoted to split on spaces.
set -f
for minute in $minutes; do
  for hour in $hours; do
    for day in $days; do
      for month in $months; do
        for weekday in $weekdays; do
          emit_interval "$minute" "$hour" "$day" "$month" "$weekday"
        done
      done
    done
  done
done
set +f

# launchd evaluates StartCalendarInterval in the machine's local timezone and
# offers no per-job override, so a mismatch would run the sync at the wrong
# clock time relative to the due-date boundaries the model reasons about.
system_tz="$(readlink /etc/localtime 2>/dev/null | sed 's#.*/zoneinfo/##' || true)"
if [[ -n "$system_tz" && "$system_tz" != "$AUTOMATION_TIMEZONE" ]]; then
  printf 'Warning: launchd schedules in system local time (%s), but\n' "$system_tz" >&2
  printf '         AUTOMATION_TIMEZONE is %s. The sync will run at\n' "$AUTOMATION_TIMEZONE" >&2
  printf '         %s clock times.\n' "$system_tz" >&2
fi

log_file="$CANVAS_SYNC_STATE_DIR/launchd.log"

# Every value below is either a repository path or a config value already
# checked for control characters; escape the XML metacharacters that remain.
xml_escape() {
  local value=$1
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  printf '%s' "${value//>/&gt;}"
}

schedule::reject_control_chars "The repository path" "$REPO_DIR"
schedule::reject_control_chars CANVAS_SYNC_STATE_DIR "$CANVAS_SYNC_STATE_DIR"

mkdir -p -- "$AGENT_DIR" "$CANVAS_SYNC_STATE_DIR"
chmod 700 "$CANVAS_SYNC_STATE_DIR"

tmp_plist="$(mktemp "$AGENT_DIR/.$LABEL.XXXXXX")"
trap 'rm -f -- "$tmp_plist"' EXIT

cat >"$tmp_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$(xml_escape "$LABEL")</string>
	<key>ProgramArguments</key>
	<array>
		<string>$(xml_escape "$REPO_DIR/scripts/run-canvas-notion-sync")</string>
	</array>
	<key>WorkingDirectory</key>
	<string>$(xml_escape "$REPO_DIR")</string>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$(xml_escape "$job_path")</string>
	</dict>
	<key>StartCalendarInterval</key>
	<array>
${intervals}	</array>
	<key>RunAtLoad</key>
	<false/>
	<key>Nice</key>
	<integer>10</integer>
	<key>ProcessType</key>
	<string>Background</string>
	<key>StandardOutPath</key>
	<string>$(xml_escape "$log_file")</string>
	<key>StandardErrorPath</key>
	<string>$(xml_escape "$log_file")</string>
</dict>
</plist>
PLIST

plutil -lint "$tmp_plist" >/dev/null ||
  config::die "The generated LaunchAgent is not a valid plist; nothing was installed."

install -m 0644 "$tmp_plist" "$PLIST"

# bootout first so a re-install replaces the running definition rather than
# failing with "service already loaded".
launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"

printf 'Installed and loaded %s (%s).\n' "$LABEL" "$CRON_SCHEDULE"
printf 'Run now:    launchctl kickstart gui/%s/%s\n' "$UID" "$LABEL"
printf 'Schedule:   launchctl print gui/%s/%s\n' "$UID" "$LABEL"
printf 'Logs:       tail -n 100 %s\n' "$log_file"
printf 'Remove:     launchctl bootout gui/%s/%s && rm %s\n' "$UID" "$LABEL" "$PLIST"
