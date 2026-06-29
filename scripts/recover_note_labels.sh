#!/usr/bin/env bash
set -euo pipefail

CURRENT_DB_DEFAULT="$HOME/Library/Containers/com.grigorym.MyNotes/Data/Library/Application Support/NotesData/notes.sqlite"
CURRENT_DB="$CURRENT_DB_DEFAULT"
BACKUP_DB=""
MODE="dry-run"

usage() {
  cat <<'EOF'
Usage:
  scripts/recover_note_labels.sh --backup /path/to/older.sqlite [--current /path/to/current.sqlite] [--apply]

Behavior:
  - dry-run by default
  - restores only note_labels
  - inserts only pairs whose note_id and label_id still exist in current DB
  - creates a timestamped backup of the current DB family before --apply
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup)
      BACKUP_DB="${2:-}"
      shift 2
      ;;
    --current)
      CURRENT_DB="${2:-}"
      shift 2
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$BACKUP_DB" ]]; then
  echo "Missing required --backup argument" >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$CURRENT_DB" ]]; then
  echo "Current DB not found: $CURRENT_DB" >&2
  exit 1
fi

if [[ ! -f "$BACKUP_DB" ]]; then
  echo "Backup DB not found: $BACKUP_DB" >&2
  exit 1
fi

require_table() {
  local db_path="$1"
  local table_name="$2"
  local count
  count="$(sqlite3 "$db_path" "select count(*) from sqlite_master where type='table' and name='$table_name';")"
  if [[ "$count" != "1" ]]; then
    echo "Required table '$table_name' not found in $db_path" >&2
    exit 1
  fi
}

for table in notes labels note_labels; do
  require_table "$CURRENT_DB" "$table"
  require_table "$BACKUP_DB" "$table"
done

current_note_labels_count="$(sqlite3 "$CURRENT_DB" "select count(*) from note_labels;")"
backup_note_labels_count="$(sqlite3 "$BACKUP_DB" "select count(*) from note_labels;")"

recoverable_count="$(
  sqlite3 "$CURRENT_DB" <<SQL
ATTACH '$BACKUP_DB' AS backup;
SELECT COUNT(*)
FROM (
  SELECT DISTINCT b.note_id, b.label_id
  FROM backup.note_labels b
  JOIN main.notes n ON n.id = b.note_id
  JOIN main.labels l ON l.id = b.label_id
  LEFT JOIN main.note_labels m
    ON m.note_id = b.note_id
   AND m.label_id = b.label_id
  WHERE m.note_id IS NULL
);
SQL
)"

missing_notes_count="$(
  sqlite3 "$CURRENT_DB" <<SQL
ATTACH '$BACKUP_DB' AS backup;
SELECT COUNT(*)
FROM backup.note_labels b
LEFT JOIN main.notes n ON n.id = b.note_id
WHERE n.id IS NULL;
SQL
)"

missing_labels_count="$(
  sqlite3 "$CURRENT_DB" <<SQL
ATTACH '$BACKUP_DB' AS backup;
SELECT COUNT(*)
FROM backup.note_labels b
LEFT JOIN main.labels l ON l.id = b.label_id
WHERE l.id IS NULL;
SQL
)"

echo "Current DB: $CURRENT_DB"
echo "Backup DB:  $BACKUP_DB"
echo "Mode:       $MODE"
echo
echo "Counts:"
echo "  current note_labels: $current_note_labels_count"
echo "  backup note_labels:  $backup_note_labels_count"
echo "  recoverable pairs:   $recoverable_count"
echo "  backup pairs missing current notes:  $missing_notes_count"
echo "  backup pairs missing current labels: $missing_labels_count"

if [[ "$MODE" == "dry-run" ]]; then
  echo
  echo "Dry run only. No changes applied."
  exit 0
fi

if [[ "$recoverable_count" == "0" ]]; then
  echo
  echo "No recoverable note_labels found. Nothing to apply."
  exit 0
fi

current_dir="$(dirname "$CURRENT_DB")"
timestamp="$(date +%Y%m%d-%H%M%S)"
recovery_backup_dir="$current_dir/backups/recovery-$timestamp"
mkdir -p "$recovery_backup_dir"

cp "$CURRENT_DB" "$recovery_backup_dir/notes.sqlite"
if [[ -f "$CURRENT_DB-wal" ]]; then
  cp "$CURRENT_DB-wal" "$recovery_backup_dir/notes.sqlite-wal"
fi
if [[ -f "$CURRENT_DB-shm" ]]; then
  cp "$CURRENT_DB-shm" "$recovery_backup_dir/notes.sqlite-shm"
fi

sqlite3 "$CURRENT_DB" <<SQL
ATTACH '$BACKUP_DB' AS backup;
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO note_labels (note_id, label_id)
SELECT DISTINCT b.note_id, b.label_id
FROM backup.note_labels b
JOIN main.notes n ON n.id = b.note_id
JOIN main.labels l ON l.id = b.label_id;
COMMIT;
SQL

after_count="$(sqlite3 "$CURRENT_DB" "select count(*) from note_labels;")"

echo
echo "Recovery applied."
echo "Backup of current DB family saved to: $recovery_backup_dir"
echo "note_labels after apply: $after_count"
