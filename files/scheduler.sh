#!/bin/bash
# Background backup scheduler.
#
# Replaces the old cron setup. Running the schedule in-process means backups:
#   - see the container environment (BACKUP_RETENTION, TZ, ...)
#   - log straight to the container stdout (visible in `docker logs`)
#   - run as the foundry user, so archives are never root-owned on the host
#
# BACKUP_INTERVAL keeps its old contract: a standard 5-field cron expression
# (minute hour day-of-month month day-of-week), e.g. "0 * * * *" for hourly.

BACKUP_SCRIPT="${BACKUP_SCRIPT:-/home/foundry/scripts/backup.sh}"
DEFAULT_INTERVAL="0 * * * *"

log() { printf '[%s] [SCHEDULER] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# --- cron expression matching ---------------------------------------------

# _cron_field_match <value> <field>
# Supports: * a b-d */n and comma-separated lists of those.
_cron_field_match() {
    local val=$1 field=$2 part lo hi step
    local parts
    IFS=',' read -ra parts <<< "$field"
    for part in "${parts[@]}"; do
        case "$part" in
            \*)
                return 0 ;;
            \*/[0-9]*)
                step=${part#*/}
                (( step > 0 && val % step == 0 )) && return 0 ;;
            [0-9]*-[0-9]*)
                lo=${part%-*}; hi=${part#*-}
                (( val >= 10#$lo && val <= 10#$hi )) && return 0 ;;
            [0-9]*)
                (( val == 10#$part )) && return 0 ;;
        esac
    done
    return 1
}

# cron_match <5-field expression> [epoch]  -> 0 when epoch (default: now) matches
cron_match() {
    local expr=$1 epoch=${2:-$(date +%s)}
    local f_min f_hour f_dom f_mon f_dow
    read -r f_min f_hour f_dom f_mon f_dow <<< "$expr"

    local min hour dom mon dow
    min=$((10#$(date -d "@$epoch" +%M)))
    hour=$((10#$(date -d "@$epoch" +%H)))
    dom=$((10#$(date -d "@$epoch" +%d)))
    mon=$((10#$(date -d "@$epoch" +%m)))
    dow=$((10#$(date -d "@$epoch" +%w)))

    _cron_field_match "$min"  "$f_min"  || return 1
    _cron_field_match "$hour" "$f_hour" || return 1
    _cron_field_match "$mon"  "$f_mon"  || return 1

    # day-of-week: allow 7 as Sunday, same as standard cron
    local dow_expr=${f_dow//7/0}

    # Standard Vixie-cron rule for day fields: when BOTH day-of-month and
    # day-of-week are restricted, either match counts; otherwise both must
    # match (an unrestricted field always matches).
    local dom_restricted=1 dow_restricted=1
    [[ $f_dom != '*' ]] && dom_restricted=0
    [[ $f_dow != '*' ]] && dow_restricted=0

    local dom_match=0 dow_match=0
    _cron_field_match "$dom" "$f_dom" && dom_match=1
    _cron_field_match "$dow" "$dow_expr" && dow_match=1

    if (( dom_restricted && dow_restricted )); then
        return 0
    elif (( dom_restricted )); then
        return $(( 1 - dow_match ))
    elif (( dow_restricted )); then
        return $(( 1 - dom_match ))
    else
        (( dom_match || dow_match ))
    fi
}

# --- main loop --------------------------------------------------------------
# (guarded so the cron_match functions can be sourced for tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

trap 'log "Scheduler stopping."; exit 0' TERM INT

expr="${BACKUP_INTERVAL:-$DEFAULT_INTERVAL}"
if [ "$(wc -w <<< "$expr")" -ne 5 ]; then
    log "[WARNING] BACKUP_INTERVAL='$expr' is not a 5-field cron expression. Using default '$DEFAULT_INTERVAL'."
    expr="$DEFAULT_INTERVAL"
fi

log "Backup schedule: '$expr' (TZ=${TZ:-UTC})"

last_fired_minute=""
while true; do
    now=$(date +%s)
    minute=$(( now / 60 ))
    if [ "$minute" != "$last_fired_minute" ] && cron_match "$expr" "$now"; then
        last_fired_minute=$minute
        log "Scheduled backup starting."
        if bash "$BACKUP_SCRIPT" --create; then
            log "Scheduled backup finished."
        else
            log "[ERROR] Scheduled backup failed (exit $?)."
        fi
    fi
    sleep 15
done
fi
