#!/bin/bash
# shellcheck shell=bash
#
# log.sh - shared logging helpers for the foundry container scripts.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/log.sh"
#
# Output format:
#   [YYYY-MM-DD HH:MM:SS] [LEVEL ] message            (level padded to 5 chars)
#   [YYYY-MM-DD HH:MM:SS] [TAG   ] [LEVEL ] message   (log_with_tag variants)
#
# Levels (LOG_LEVEL env, default "info"):
#   trace|debug -> everything, info -> info and up, warn, error
#
# Design constraints - this file is sourced by other scripts, sometimes more
# than once, sometimes from inside a script that is itself sourced:
#   - no 'set -e', no 'exit', no side effects except function definitions
#   - double-sourcing is a no-op (LOG_SH_LOADED guard)
#   - every variable it uses is either LOG_* prefixed or local
#   - colour codes are emitted only when stdout is a terminal ([ -t 1 ])

# --- double-source guard ----------------------------------------------------
if [ -n "${LOG_SH_LOADED:-}" ]; then
    return 0 2>/dev/null || true
fi
LOG_SH_LOADED=1

# --- tunables (all LOG_* so they never clash with the sourcing script) ------
# LOG_LEVEL: trace|debug|info|warn|error
if [ -z "${LOG_LEVEL:-}" ]; then LOG_LEVEL=info; fi
# Colour codes are stored as escape text and expanded with printf '%b'.
if [ -z "${LOG_COLOR_TRACE:-}" ];  then LOG_COLOR_TRACE=''; fi            # none
if [ -z "${LOG_COLOR_INFO:-}" ];   then LOG_COLOR_INFO='\033[0;32m'; fi   # green
if [ -z "${LOG_COLOR_WARN:-}" ];   then LOG_COLOR_WARN='\033[0;33m'; fi   # yellow
if [ -z "${LOG_COLOR_ERROR:-}" ];  then LOG_COLOR_ERROR='\033[0;31m'; fi  # red
if [ -z "${LOG_COLOR_STEP:-}" ];   then LOG_COLOR_STEP='\033[0;36m'; fi   # cyan
if [ -z "${LOG_COLOR_RESET:-}" ];  then LOG_COLOR_RESET='\033[0m'; fi
if [ -z "${LOG_BANNER_RULE:-}" ];  then
    LOG_BANNER_RULE='======================================================================='
fi

# --- internals --------------------------------------------------------------

# log_threshold -> numeric threshold of the active LOG_LEVEL
log_threshold() {
    case "${LOG_LEVEL:-info}" in
        trace|debug) printf '0\n' ;;
        warn)        printf '2\n' ;;
        error)       printf '3\n' ;;
        *)           printf '1\n' ;;
    esac
}

# _log_want <numeric level> -> 0 when a message of that level should be shown
_log_want() {
    local want=$1
    [ "$(log_threshold)" -le "$want" ]
}

# _log_norm <level> -> upper-case level name
_log_norm() {
    local lvl=${1:-info}
    case "$lvl" in
        *[[:lower:]]*) printf '%s' "$lvl" | tr '[:lower:]' '[:upper:]' ;;
        *)             printf '%s' "$lvl" ;;
    esac
}

# _log_print <LEVEL> <TAG> <MESSAGE>
# Single output line. LEVEL: trace|debug|info|warn|error|step|banner (any case).
# Empty TAG omits the tag block. ERROR goes to stderr, rest to stdout.
_log_print() {
    local level tag msg upper num color line err=0
    level=${1:-info}; tag=${2:-}; msg=${3-}
    upper=$(_log_norm "$level")
    case "$upper" in
        TRACE|DEBUG)  num=0; color="$LOG_COLOR_TRACE" ;;
        INFO)         num=1; color="$LOG_COLOR_INFO" ;;
        WARN|WARNING) num=2; color="$LOG_COLOR_WARN" ;;
        ERROR)        num=3; color="$LOG_COLOR_ERROR"; err=1 ;;
        STEP|BANNER)  num=1; color="$LOG_COLOR_STEP" ;;
        *)            num=1; color='' ;;
    esac
    _log_want "$num" || return 0
    line="[$(date '+%Y-%m-%d %H:%M:%S')]"
    if [ -n "$tag" ]; then
        line="$line [$tag]"
    fi
    line="$line [$(printf '%-5s' "$upper")] $msg"
    if [ -t 1 ] && [ -n "$color" ]; then
        if [ "$err" -eq 1 ]; then
            printf '%b%s%b\n' "$color" "$line" "$LOG_COLOR_RESET" >&2
        else
            printf '%b%s%b\n' "$color" "$line" "$LOG_COLOR_RESET"
        fi
    else
        if [ "$err" -eq 1 ]; then
            printf '%s\n' "$line" >&2
        else
            printf '%s\n' "$line"
        fi
    fi
    return 0
}

# _log_raw <COLOR> <TEXT> - line without timestamp/level prefix (step/banner)
_log_raw() {
    local color=${1:-} text=${2-}
    if [ -t 1 ] && [ -n "$color" ]; then
        printf '%b%s%b\n' "$color" "$text" "$LOG_COLOR_RESET"
    else
        printf '%s\n' "$text"
    fi
    return 0
}

# --- public API -------------------------------------------------------------

# log_trace <message>       (log_debug is an alias)
log_trace() { _log_print TRACE '' "$*"; }
log_debug() { _log_print TRACE '' "$*"; }

# log_info <message>
log_info() { _log_print INFO '' "$*"; }

# log_warn <message>
log_warn() { _log_print WARN '' "$*"; }

# log_error <message>  -> stderr
log_error() { _log_print ERROR '' "$*"; }

# log_with_tag <LEVEL> <TAG> <message> - generic tagged line
log_with_tag() {
    local level tag
    level=${1:-info}; tag=${2:-}
    if [ $# -gt 2 ]; then shift 2; else set --; fi
    _log_print "$level" "$tag" "$*"
    return 0
}

# Convenience wrappers, e.g. log_info_tag SCHEDULER "Backup started"
log_info_tag()  { _log_print INFO  "${1:-}" "${2-}"; }
log_warn_tag()  { _log_print WARN  "${1:-}" "${2-}"; }
log_error_tag() { _log_print ERROR "${1:-}" "${2-}"; }

# log_step [phase-number] <text>
# Blank line, then '== Phase N: text ==' (or '== text ==' with no number)
log_step() {
    _log_want 1 || return 0
    local label
    case "${1:-}" in
        ''|*[!0-9]*) label="$*" ;;
        *)           label="Phase $1: $2" ;;
    esac
    printf '\n'
    _log_raw "$LOG_COLOR_STEP" "== $label =="
    return 0
}

# log_banner <title> [key: value ...]
# Header block: title plus one line per remaining argument.
log_banner() {
    _log_want 1 || return 0
    local title arg
    title=${1:-}
    if [ $# -gt 0 ]; then shift; fi
    printf '\n'
    _log_raw "$LOG_COLOR_STEP" "$LOG_BANNER_RULE"
    _log_raw "$LOG_COLOR_STEP" "== ${title}"
    for arg in "$@"; do
        _log_raw "$LOG_COLOR_STEP" "==   ${arg}"
    done
    _log_raw "$LOG_COLOR_STEP" "$LOG_BANNER_RULE"
    return 0
}
