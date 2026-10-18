#!/bin/bash
# Backup tool for Foundry dedicated server save files.
#
# Usage:
#   backup.sh                       create a backup (default action)
#   backup.sh --create              same as above
#   backup.sh --list                list existing backups
#   backup.sh --restore <f|latest> [--now] [--yes]
#                                   restore a backup. Without --now the restore
#                                   is deferred: it is applied automatically on
#                                   the next container start (safe while the
#                                   server keeps running). With --now the
#                                   restore happens immediately and requires
#                                   the server to be stopped.
#
# Environment:
#   PERSISTENT_DATA    (default /home/foundry/persistent_data)
#   BACKUP_RETENTION   number of archives to keep (default 10)
#   MIN_FREE_MB        minimum free space required on the backup volume (default 500)

set -u

# Shared logging helpers.
source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

LOC_DIR="${PERSISTENT_DATA:-/home/foundry/persistent_data}"
BACKUP_DIR="$LOC_DIR/backup"
PENDING_FILE="$LOC_DIR/.restore_pending"
PREFIX="foundry_backup-"
SUFFIX=".tar.gz"
DEFAULT_RETENTION=10
MIN_FREE_MB="${MIN_FREE_MB:-500}"

SAVE_DIR="$LOC_DIR/save"
CONTINUE_FILE="$LOC_DIR/continue_game.json"

# Tagged logging: keeps the [BACKUP] tag, formatting lives in log.sh.
log()  { log_info_tag BACKUP "$*"; }
err()  { log_error_tag BACKUP "$*"; }

human_size() {
    awk -v b="${1:-0}" 'BEGIN {
        if      (b >= 1073741824) printf "%.1f GB", b/1073741824;
        else if (b >= 1048576)    printf "%.1f MB", b/1048576;
        else                      printf "%.1f KB", b/1024;
    }'
}

file_bytes() { stat -c %s "$1" 2>/dev/null || echo 0; }

validate_retention() {
    local val="${BACKUP_RETENTION:-$DEFAULT_RETENTION}"
    if [[ "$val" =~ ^[0-9]+$ ]] && (( 10#$val > 0 )); then
        BACKUP_RETENTION=$((10#$val))
    else
        log "[WARNING] '$val' is not a valid retention count. Using $DEFAULT_RETENTION."
        BACKUP_RETENTION=$DEFAULT_RETENTION
    fi
}

sorted_backups() {
    # oldest first, one path per line; only regular archives
    find "$BACKUP_DIR" -maxdepth 1 -name "${PREFIX}*${SUFFIX}" -type f \
        -printf '%T@ %p\n' 2>/dev/null | sort -n | cut -d' ' -f2-
}

do_list() {
    mkdir -p "$BACKUP_DIR"
    local count=0 b
    log "Backups in $BACKUP_DIR (oldest first):"
    while IFS= read -r b; do
        count=$((count+1))
        printf '  %s  %s\n' "$(human_size "$(file_bytes "$b")")" "$b"
    done < <(sorted_backups)
    if (( count == 0 )); then
        log "  (none)"
    fi
}

do_create() {
    validate_retention
    mkdir -p "$BACKUP_DIR"

    if [ ! -d "$SAVE_DIR" ]; then
        err "No save directory yet ($SAVE_DIR). World has probably not been generated/started. Skipping backup."
        return 0
    fi

    # --- disk space guard: current save size + headroom ---
    local save_kb free_kb min_free_kb
    save_kb=$(du -sk "$SAVE_DIR" 2>/dev/null | cut -f1)
    free_kb=$(df -k --output=avail "$BACKUP_DIR" 2>/dev/null | tail -n1 | tr -d ' ')
    min_free_kb=$(( ${save_kb:-0} + MIN_FREE_MB * 1024 ))
    if [ -n "$free_kb" ] && (( free_kb < min_free_kb )); then
        err "Not enough disk space: $(human_size $((free_kb*1024))) free, need ~$(human_size $((min_free_kb*1024))) (save + ${MIN_FREE_MB} MB headroom). Backup skipped."
        return 1
    fi

    local start_ts=$SECONDS archive tmp delete_count=0
    archive="${PREFIX}$(date '+%Y-%m-%d_%H-%M-%S')${SUFFIX}"
    # second-granularity names can collide (e.g. manual backup right after a
    # scheduled one); never overwrite an existing archive
    local n=1
    while [ -e "$BACKUP_DIR/$archive" ]; do
        archive="${PREFIX}$(date '+%Y-%m-%d_%H-%M-%S')-$n${SUFFIX}"
        n=$((n+1))
    done
    tmp="$BACKUP_DIR/.$archive.partial"

    # continue_game.json only exists after the first session; include it when present
    local members=(save)
    [ -f "$CONTINUE_FILE" ] && members+=(continue_game.json)

    if ! tar -czf "$tmp" -C "$LOC_DIR" "${members[@]}"; then
        rm -f "$tmp"
        err "tar failed. No backup created."
        return 1
    fi

    # integrity check before promoting the archive
    if ! tar -tzf "$tmp" > /dev/null 2>&1; then
        rm -f "$tmp"
        err "Integrity check failed. Discarding $archive."
        return 1
    fi
    mv "$tmp" "$BACKUP_DIR/$archive"

    # --- retention (count based, oldest first) ---
    local -a backups
    mapfile -t backups < <(sorted_backups)
    local total=${#backups[@]} i
    if (( total > BACKUP_RETENTION )); then
        delete_count=$(( total - BACKUP_RETENTION ))
        for (( i = 0; i < delete_count; i++ )); do
            rm -f -- "${backups[i]}"
        done
    fi
    mapfile -t backups < <(sorted_backups)

    local size dur total_size
    size=$(human_size "$(file_bytes "$BACKUP_DIR/$archive")")
    dur=$(( SECONDS - start_ts ))
    total_size=$(( $(du -ck "$BACKUP_DIR" 2>/dev/null | tail -n1 | cut -f1) * 1024 ))
    log "Created $archive ($size, ${dur}s) · pruned $delete_count · keeping ${#backups[@]} of $BACKUP_RETENTION · total $total_size"
}

resolve_target() {
    local target=$1
    if [ "$target" = "latest" ]; then
        sorted_backups | tail -n1
    else
        # accept bare filename or full path
        if [ -f "$target" ]; then echo "$target"
        elif [ -f "$BACKUP_DIR/$target" ]; then echo "$BACKUP_DIR/$target"
        else echo ""
        fi
    fi
}

do_restore() {
    local target=$1 immediate=$2 assume_yes=$3
    local archive
    archive=$(resolve_target "$target")

    if [ -z "$archive" ] || [ ! -f "$archive" ]; then
        err "Backup '$target' not found. Use --list to see available backups."
        return 1
    fi
    if ! tar -tzf "$archive" > /dev/null 2>&1; then
        err "Backup '$archive' is corrupt (integrity check failed). Refusing to restore."
        return 1
    fi

    if [ "$immediate" != "yes" ]; then
        printf '%s\n' "$archive" > "$PENDING_FILE"
        log "Restore of $(basename "$archive") scheduled. Restart the container to apply it:"
        log "  docker restart <container>   (or: docker compose up -d --force-recreate)"
        log "The current save will be kept as a safety copy before restoring."
        return 0
    fi

    if [ "$assume_yes" != "yes" ]; then
        err "Immediate restore overwrites the current save. The server must be stopped. Re-run with --yes to confirm."
        return 1
    fi

    local quarantine="$LOC_DIR/pre_restore_$(date '+%Y-%m-%d_%H-%M-%S')"
    rm -f "$PENDING_FILE"   # a --now restore supersedes any deferred one
    mkdir -p "$quarantine"
    [ -d "$SAVE_DIR" ] && mv "$SAVE_DIR" "$quarantine/save"
    [ -f "$CONTINUE_FILE" ] && mv "$CONTINUE_FILE" "$quarantine/continue_game.json"

    if tar -xzf "$archive" -C "$LOC_DIR"; then
        log "Restored $(basename "$archive"). Previous save moved to $(basename "$quarantine")."
    else
        err "Extraction failed! Restoring safety copy..."
        [ -d "$quarantine/save" ] && mv "$quarantine/save" "$SAVE_DIR"
        [ -f "$quarantine/continue_game.json" ] && mv "$quarantine/continue_game.json" "$CONTINUE_FILE"
        return 1
    fi
}

usage() {
    sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
}

# --- argument parsing -------------------------------------------------------

ACTION="create"
TARGET=""
IMMEDIATE="no"
ASSUME_YES="no"

while [ $# -gt 0 ]; do
    case "$1" in
        --create)        ACTION="create" ;;
        --list)          ACTION="list" ;;
        --restore)       ACTION="restore"; TARGET="${2:-}"; shift ;;
        --now)           IMMEDIATE="yes" ;;
        --yes)           ASSUME_YES="yes" ;;
        -h|--help)       usage; exit 0 ;;
        *)               err "Unknown argument: $1"; usage; exit 1 ;;
    esac
    shift
done

case "$ACTION" in
    create)  do_create ;;
    list)    do_list ;;
    restore)
        if [ -z "$TARGET" ]; then err "--restore needs a backup filename or 'latest'."; exit 1; fi
        do_restore "$TARGET" "$IMMEDIATE" "$ASSUME_YES" ;;
esac
