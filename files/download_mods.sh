#!/bin/bash
set -eo pipefail

# Shared logging helpers (this file is sourced by start.sh from another cwd,
# so resolve the path from BASH_SOURCE, not from $0 or the cwd).
source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

# Configuration
MODLIST_FILE="$server_files/Mods/modList.json"
APP_ID=983870
MODS_TXT="$server_files/mods.txt"
STEAMCMD_LOG="$server_files/steamcmd.log"
DOWNLOAD_DIR="$server_files/downloaded_mods"
CONTENT_DIR="$DOWNLOAD_DIR/steamapps/workshop/content/$APP_ID"
MODS_DIR="$server_files/Mods"

export APP_ID 

# Error handling
fail() {
    log_error "$1"
    [[ -f "$STEAMCMD_LOG" ]] && log_error "Check logs: $STEAMCMD_LOG"
    exit 1
}

# Validate modList.json
validate_modlist() {
    # Check file exists
    [[ ! -f "$MODLIST_FILE" ]] && fail "modList.json not found at $MODLIST_FILE"
    
    # Check valid JSON structure
    if ! jq -e '.mods' "$MODLIST_FILE" >/dev/null; then
        fail "Invalid JSON or missing 'mods' array in modList.json"
    fi
    
    # Check for at least one valid mod
    if ! jq -e '.mods[] | select(.workshopFileId?)' "$MODLIST_FILE" >/dev/null; then
        fail "No valid mods with workshopFileId found"
    fi
}

# Generate complete mods.txt
generate_modlist() {
    log_info "Generating complete $MODS_TXT..."
    
    # Start with SteamCMD commands
    cat <<EOF > "$MODS_TXT"
@NoPromptForPassword 1
@ShutdownOnFailedCommand 1
force_install_dir "$server_files\downloaded_mods"
login anonymous
EOF

    # Add all mod download commands
    jq -r --arg appid "$APP_ID" '.mods[] | select(.workshopFileId?) | "workshop_download_item \($appid) \(.workshopFileId) validate"' \
        "$MODLIST_FILE" >> "$MODS_TXT" || fail "Failed to generate mod list"
    
    # Add final commands
    echo "quit" >> "$MODS_TXT"
    
    # Count mods for logging
    MOD_COUNT=$(jq -r '.mods[] | select(.workshopFileId?) | .workshopFileId' "$MODLIST_FILE" | wc -l)
    log_info "Generated commands for $MOD_COUNT mod(s)"
}

# Copy mods to final destination
copy_mods() {
    log_info "=== Copying all mods to the Mods folder ==="
    
    # Copy each mod individually to handle errors per mod
    for mod_id in $(ls "$CONTENT_DIR"); do
        mod_source="$CONTENT_DIR/$mod_id"
        mod_dest="$MODS_DIR/$mod_id"
        
        log_info "Copying mod $mod_id..."
        if [ -d "$mod_source" ]; then
            cp -rf "$mod_source" "$mod_dest" || log_warn "Failed to copy mod $mod_id"
        else
            log_warn "Mod $mod_id not found in download directory"
        fi
    done
    
    log_info "=== Mod copy completed ==="
}

# Main execution
{
    log_info "=== Mod Download Started $(date) ==="
    
    # Validate input
    validate_modlist
    
    # Create mod list
    generate_modlist
    
    # Single SteamCMD execution
    log_info "Starting bulk download via SteamCMD..."
    log_info "Using command file:"
    cat "$MODS_TXT"
    
    steamcmd +runscript "$MODS_TXT" || fail "SteamCMD download failed"
    
    # Copy downloaded mods to final location
    copy_mods
    
    log_info "=== All operations completed successfully ==="
} | tee -a "$STEAMCMD_LOG"
