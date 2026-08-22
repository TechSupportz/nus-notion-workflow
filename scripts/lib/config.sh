# shellcheck shell=bash
#
# Shared configuration loader and validator.
#
# Source this from a script in scripts/ after defining REPO_DIR:
#
#   source "$REPO_DIR/scripts/lib/config.sh"
#   config::load
#   config::need_bins canvas jq
#   config::need_notion
#
# Every value comes from config.local.sh. Nothing here reads the environment
# except as an explicit override documented in config.example.sh.

config::die() {
  printf '%s\n' "$@" >&2
  exit 78 # EX_CONFIG
}

# Load config.local.sh and apply defaults for optional settings.
config::load() {
  local config_path="$REPO_DIR/config.local.sh"

  if [[ ! -f "$config_path" ]]; then
    config::die \
      "Missing configuration: $config_path" \
      "" \
      "Create it from the committed example:" \
      "  cp '$REPO_DIR/config.example.sh' '$config_path'" \
      "  chmod 600 '$config_path'" \
      "" \
      "Then fill in the Notion IDs and Canvas settings it describes."
  fi

  # shellcheck source=/dev/null
  source "$config_path"

  # Optional settings, defaulted here so `set -u` is safe downstream.
  : "${CANVAS_INSTANCE_NAME:=}"
  : "${CANVAS_TERM_NAME_REGEX:=}"
  : "${CANVAS_SYNC_COURSE_IDS:=}"
  : "${CODEX_MODEL:=gpt-5.6-luna}"
  : "${CANVAS_SYNC_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/notion-workflow-canvas-sync}"
  : "${CANVAS_SYNC_MAX_FILE_BYTES:=15728640}"
  : "${CANVAS_SYNC_MAX_EXTRACTED_BYTES:=500000}"
  : "${AUTOMATION_TIMEZONE:=}"
  : "${AUTOMATION_SCHEDULER:=systemd}"
  : "${SYSTEMD_ON_CALENDAR:=}"
  : "${CRON_SCHEDULE:=}"

  # Canvas CLI argument array, empty when no named instance is configured.
  CANVAS_INSTANCE_ARGS=()
  if [[ -n "$CANVAS_INSTANCE_NAME" ]]; then
    CANVAS_INSTANCE_ARGS=(--instance "$CANVAS_INSTANCE_NAME")
  fi
}

# Resolve one binary variable, either from an explicit override or from PATH.
# Appends to CONFIG_MISSING_BINS rather than failing, so all gaps report at once.
config::_resolve_bin() {
  local var_name=$1 command_name=$2 configured resolved
  configured="${!var_name:-}"

  if [[ -n "$configured" ]]; then
    # -x alone is satisfied by directories, so require a regular file too.
    if [[ ! -f "$configured" || ! -x "$configured" ]]; then
      config::die "$var_name is set to '$configured', which is not an executable file."
    fi
    return 0
  fi

  if resolved="$(command -v -- "$command_name" 2>/dev/null)"; then
    printf -v "$var_name" '%s' "$resolved"
  else
    CONFIG_MISSING_BINS+=("$command_name")
  fi
}

# Require the named tools. Accepts: canvas, jq, codex, flock, systemctl, unzip.
config::need_bins() {
  CONFIG_MISSING_BINS=()

  local tool
  for tool in "$@"; do
    case "$tool" in
      canvas) config::_resolve_bin CANVAS_BIN canvas ;;
      jq) config::_resolve_bin JQ_BIN jq ;;
      codex) config::_resolve_bin CODEX_BIN codex ;;
      *)
        if ! command -v -- "$tool" >/dev/null 2>&1; then
          CONFIG_MISSING_BINS+=("$tool")
        fi
        ;;
    esac
  done

  if [[ ${#CONFIG_MISSING_BINS[@]} -gt 0 ]]; then
    config::die \
      "Required tools are not installed or not on PATH:" \
      "  ${CONFIG_MISSING_BINS[*]}" \
      "" \
      "Install them and retry. Only canvas, jq, and codex have a config override" \
      "(CANVAS_BIN, JQ_BIN, CODEX_BIN in config.local.sh); the rest must be on PATH."
  fi
}

# Reject a non-numeric byte limit here rather than at the arithmetic comparison
# in hydrate-canvas-file-changes, which would fail mid-sync.
config::_check_bytes() {
  local var_name=$1 value="${!1:-}"
  [[ "$value" =~ ^[0-9]+$ ]] ||
    config::die "$var_name must be a whole number of bytes. Got: '$value'"
}

config::_check_id() {
  local var_name=$1 value="${!1:-}"
  [[ -n "$value" ]] ||
    config::die "$var_name is empty in config.local.sh."
  [[ "$value" =~ ^[0-9a-fA-F]{32}$ || "$value" =~ ^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$ ]] ||
    config::die "$var_name is not a Notion page ID: '$value'" \
      "Expected 32 hex characters, or the dashed UUID form."
}

config::_check_data_source() {
  local var_name=$1 value="${!1:-}"
  [[ -n "$value" ]] ||
    config::die "$var_name is empty in config.local.sh."
  [[ "$value" =~ ^collection://[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$ ]] ||
    config::die "$var_name is not a data-source URI: '$value'" \
      "Expected the form collection://<uuid>."
}

# Validate the Notion identifiers the automation actually writes through.
config::need_notion() {
  config::_check_id NOTION_AGENT_GUIDE_PAGE_ID
  config::_check_id NOTION_CHANGELOG_PAGE_ID
  config::_check_data_source NOTION_TASKS_DATA_SOURCE_URI
  config::_check_data_source NOTION_STACKS_DATA_SOURCE_URI
}

# Validate course selection and the timezone. Requires JQ_BIN to be resolved.
config::need_canvas() {
  if [[ -n "$CANVAS_SYNC_COURSE_IDS" ]]; then
    [[ "$CANVAS_SYNC_COURSE_IDS" =~ ^[0-9]+([[:space:]]*,[[:space:]]*[0-9]+)*$ ]] ||
      config::die \
        "CANVAS_SYNC_COURSE_IDS must be comma-separated integers." \
        "Got: '$CANVAS_SYNC_COURSE_IDS'"
  elif [[ -n "$CANVAS_TERM_NAME_REGEX" ]]; then
    "$JQ_BIN" -n --arg pattern "$CANVAS_TERM_NAME_REGEX" \
      '"" | test($pattern; "i")' >/dev/null 2>&1 ||
      config::die \
        "CANVAS_TERM_NAME_REGEX is not a valid regular expression:" \
        "  '$CANVAS_TERM_NAME_REGEX'"
  else
    config::die \
      "No Canvas course selection is configured." \
      "" \
      "Set one of these in config.local.sh:" \
      "  CANVAS_TERM_NAME_REGEX  — matched against the Canvas term name" \
      "  CANVAS_SYNC_COURSE_IDS  — an explicit comma-separated course list" \
      "" \
      "Inspect your term names with:" \
      "  canvas courses list --enrollment-type student --include term -o json"
  fi

  config::_check_bytes CANVAS_SYNC_MAX_FILE_BYTES
  config::_check_bytes CANVAS_SYNC_MAX_EXTRACTED_BYTES

  [[ -n "$AUTOMATION_TIMEZONE" ]] ||
    config::die "AUTOMATION_TIMEZONE is empty in config.local.sh."

  if [[ -d /usr/share/zoneinfo ]] &&
    [[ ! -f "/usr/share/zoneinfo/$AUTOMATION_TIMEZONE" ]]; then
    config::die \
      "AUTOMATION_TIMEZONE is not a timezone known to this host:" \
      "  '$AUTOMATION_TIMEZONE'" \
      "Expected an IANA name such as Asia/Singapore or America/New_York."
  fi
}
