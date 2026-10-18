#!/bin/bash
# Optional web admin UI for the Foundry container (see webui.py).
#
# Started in the background from start.sh. Without WEBUI=true - or without a
# WEBUI_TOKEN - this is a no-op so the container boots exactly as before.

# Shared logging helpers.
source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

if [ "${WEBUI:-false}" = true ] && [ -n "${WEBUI_TOKEN:-}" ]; then
    log_info "Starting web UI on port ${WEBUI_PORT:-8080}"
    exec python3 "$SCRIPT_DIR/webui.py"
fi

if [ "${WEBUI:-false}" = true ]; then
    log_warn "WEBUI is enabled but WEBUI_TOKEN is not set - web admin UI stays disabled"
else
    log_warn "Web admin UI disabled (WEBUI is not true)"
fi
exit 0
