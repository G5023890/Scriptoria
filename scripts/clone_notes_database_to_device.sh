#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

DEVICE_NAME="${DEVICE_NAME:-GriPhone}"
BUNDLE_ID="${BUNDLE_ID:-com.grigorym.MyNotes}"
SOURCE_DIR="${SOURCE_DIR:-$HOME/Library/Application Support/NotesData}"
SNAPSHOT_DIR="${SNAPSHOT_DIR:-$PROJECT_DIR/dist/NotesDataSnapshot}"
DEVICE_DESTINATION="${DEVICE_DESTINATION:-Library/Application Support/NotesData}"
SKIP_LAUNCH="${SKIP_LAUNCH:-0}"
EXPORT_ONLY="${EXPORT_ONLY:-0}"

log() {
  echo "[clone] $*"
}

usage() {
  cat <<'EOF'
Usage: scripts/clone_notes_database_to_device.sh [--export-only] [--skip-launch]

Environment overrides:
  DEVICE_NAME          Device name or UDID (default: GriPhone)
  BUNDLE_ID            App bundle id (default: com.grigorym.MyNotes)
  SOURCE_DIR           Local NotesData directory to snapshot
  SNAPSHOT_DIR         Output directory for the staged snapshot
  DEVICE_DESTINATION   Destination path inside the app data container
  SKIP_LAUNCH          Set to 1 to skip launching the app after copy
  EXPORT_ONLY          Set to 1 to only export the snapshot locally
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --export-only)
      EXPORT_ONLY=1
      ;;
    --skip-launch)
      SKIP_LAUNCH=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

escape_sqlite_path() {
  printf "%s" "$1" | sed "s/'/''/g"
}

require_file() {
  local path="$1"
  local description="$2"
  if [[ ! -e "$path" ]]; then
    echo "Missing $description: $path" >&2
    exit 1
  fi
}

export_snapshot() {
  local source_db="$SOURCE_DIR/notes.sqlite"
  require_file "$SOURCE_DIR" "source data directory"
  require_file "$source_db" "source database"

  log "Preparing snapshot at: $SNAPSHOT_DIR"
  rm -rf "$SNAPSHOT_DIR"
  mkdir -p "$SNAPSHOT_DIR"

  local snapshot_db="$SNAPSHOT_DIR/notes.sqlite"
  log "Backing up SQLite database"
  printf ".backup '%s'\n" "$(escape_sqlite_path "$snapshot_db")" | sqlite3 "$source_db"

  for subdir in attachments thumbnails; do
    local source_subdir="$SOURCE_DIR/$subdir"
    local destination_subdir="$SNAPSHOT_DIR/$subdir"
    if [[ -d "$source_subdir" ]]; then
      log "Copying $subdir"
      /usr/bin/ditto --norsrc "$source_subdir" "$destination_subdir"
    else
      log "Creating empty $subdir"
      mkdir -p "$destination_subdir"
    fi
  done

  find "$SNAPSHOT_DIR" -name '.DS_Store' -delete

  cat > "$SNAPSHOT_DIR/clone-manifest.txt" <<EOF
source_dir=$SOURCE_DIR
exported_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
bundle_id=$BUNDLE_ID
device_name=$DEVICE_NAME
EOF

  log "Snapshot ready: $SNAPSHOT_DIR"
}

terminate_running_app_if_needed() {
  local pid
  pid="$(
    xcrun devicectl device info processes \
      --device "$DEVICE_NAME" \
      --filter "bundleIdentifier == '$BUNDLE_ID'" \
      --columns pid \
      --hide-default-columns \
      --hide-headers \
      --quiet 2>/dev/null | awk 'NF {print $1; exit}'
  )"

  if [[ -n "${pid:-}" ]]; then
    log "Terminating running app process $pid"
    xcrun devicectl device process terminate --device "$DEVICE_NAME" --pid "$pid" --kill --quiet >/dev/null
  fi
}

copy_snapshot_to_device() {
  log "Copying snapshot to $DEVICE_NAME"
  xcrun devicectl device copy to \
    --device "$DEVICE_NAME" \
    --source "$SNAPSHOT_DIR/notes.sqlite" \
    --source "$SNAPSHOT_DIR/attachments" \
    --source "$SNAPSHOT_DIR/thumbnails" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" \
    --destination "$DEVICE_DESTINATION" \
    --remove-existing-content true \
    --quiet
}

launch_app_on_device() {
  if [[ "$SKIP_LAUNCH" == "1" ]]; then
    log "Skipping launch"
    return 0
  fi

  log "Launching app on $DEVICE_NAME"
  xcrun devicectl device process launch \
    --device "$DEVICE_NAME" \
    "$BUNDLE_ID" \
    --quiet
}

export_snapshot

if [[ "$EXPORT_ONLY" == "1" ]]; then
  log "Export only requested; stopping after snapshot export"
  exit 0
fi

terminate_running_app_if_needed
copy_snapshot_to_device
launch_app_on_device

log "Clone complete"
