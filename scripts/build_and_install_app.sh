#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

PROJECT_PATH="${PROJECT_PATH:-$PROJECT_DIR/MyNotes.xcodeproj}"
SCHEME="${SCHEME:-MyNotes-macOS}"
CONFIGURATION="${CONFIGURATION:-Debug}"
APP_NAME="${APP_NAME:-MyNotes.app}"
INSTALL_DIR="${INSTALL_DIR:-/Applications/$APP_NAME}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/MyNotes-codex}"

log() {
  echo "[build] $*"
}

log "Building $SCHEME ($CONFIGURATION)"
xcodebuild \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_SOURCE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"
if [[ ! -d "$APP_SOURCE" ]]; then
  echo "Built app not found: $APP_SOURCE" >&2
  exit 1
fi

log "Installing to $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
/usr/bin/ditto "$APP_SOURCE" "$INSTALL_DIR"
xattr -cr "$INSTALL_DIR" >/dev/null 2>&1 || true

if [[ "$SCHEME" == "MyNotes-macOS" ]]; then
  LEGACY_DATA_DIR="$HOME/Library/Application Support/NotesData"
  SANDBOX_DATA_DIR="$HOME/Library/Containers/com.grigorym.MyNotes/Data/Library/Application Support/NotesData"
  if [[ -f "$LEGACY_DATA_DIR/notes.sqlite" && ! -f "$SANDBOX_DATA_DIR/notes.sqlite" ]]; then
    log "Migrating legacy NotesData into sandbox container"
    mkdir -p "$(dirname "$SANDBOX_DATA_DIR")"
    /usr/bin/ditto "$LEGACY_DATA_DIR" "$SANDBOX_DATA_DIR"
  fi
fi

log "Built: $APP_SOURCE"
log "Installed: $INSTALL_DIR"
