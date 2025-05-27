#!/bin/bash
set -eo pipefail

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
    echo "[ERROR] $1" >&2
    [[ -f "$STEAMCMD_LOG" ]] && echo "Check logs: $STEAMCMD_LOG" >&2
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
    echo "Generating complete $MODS_TXT..."
    
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
    echo "Generated commands for $MOD_COUNT mod(s)"
}

# Copy mods to final destination
copy_mods() {
    echo "=== Copying all mods to the Mods folder ==="
    
    # Copy each mod individually to handle errors per mod
    for mod_id in $(ls "$CONTENT_DIR"); do
        mod_source="$CONTENT_DIR/$mod_id"
        mod_dest="$MODS_DIR/$mod_id"
        
        echo "Copying mod $mod_id..."
        if [ -d "$mod_source" ]; then
            cp -rf "$mod_source" "$mod_dest" || echo "[WARNING] Failed to copy mod $mod_id"
        else
            echo "[WARNING] Mod $mod_id not found in download directory"
        fi
    done
    
    echo "=== Mod copy completed ==="
}

# Main execution
{
    echo "=== Mod Download Started $(date) ==="
    
    # Validate input
    validate_modlist
    
    # Create mod list
    generate_modlist
    
    # Single SteamCMD execution
    echo "Starting bulk download via SteamCMD..."
    echo "Using command file:"
    cat "$MODS_TXT"
    
    steamcmd +runscript "$MODS_TXT" || fail "SteamCMD download failed"
    
    # Copy downloaded mods to final location
    copy_mods
    
    echo "=== All operations completed successfully ==="
} | tee -a "$STEAMCMD_LOG"
