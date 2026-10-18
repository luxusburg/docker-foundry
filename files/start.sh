#!/bin/bash
# Location of server data and save data for docker

# Shared logging helpers (timestamped, levelled output).
source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

# Check if old volume mounts exists from before 1.3 # we check for 2 but only warned about 1
if [ -d '/mnt/foundry/server' ] || [ -d '/mnt/foundry/persistentdata' ]; then
    log_error "Old docker volume setup found!"
    log_error "Change your volume from /your/path/:/mnt/foundry/server to /your/path/:/home/foundry/server_files"
    log_error "Change your volume from /your/path/:/mnt/foundry/persistentdata to /your/path/:/home/foundry/persistent_data"
    log_error "Check release notes 1.3 for more information!"
    log_error "https://github.com/luxusburg/docker-foundry/releases"
    exit 1
fi

server_files=/home/foundry/server_files
persistent_data=/home/foundry/persistent_data

LOG_IMAGE_VERSION="dev"
if [ -f /home/foundry/scripts/VERSION ]; then
    LOG_IMAGE_VERSION=$(cat /home/foundry/scripts/VERSION)
fi
log_banner "FOUNDRY DEDICATED SERVER CONTAINER" \
    "Image version: $LOG_IMAGE_VERSION" \
    "World: ${WORLD_NAME:-FoundryDockerWorld}" \
    "TZ: ${TZ:-UTC}" \
    "PUID:PGID: ${PUID:-1000}:${PGID:-1000}" \
    "Mods: ${ENABLE_MODS:-false}" \
    "Beta branch: ${BETANAME:-none}"

log_info "Server files location is set to : $server_files"
log_info "Save files location is set to : $persistent_data"

# Aborts the boot if the steamcmd download did not produce a usable server.
verify_server_install() {
    if [ ! -f "$server_files/FoundryDedicatedServer.exe" ]; then
        log_error '[ERROR] Foundry server installation failed - FoundryDedicatedServer.exe missing'
        exit 1
    fi
}

# Apply a deferred restore (backup.sh --restore without --now) before the
# server starts, so the game loads the restored save.
if [ -f "$persistent_data/.restore_pending" ]; then
    pending_backup=$(cat "$persistent_data/.restore_pending")
    log_info "Pending restore found: $pending_backup"
    PERSISTENT_DATA="$persistent_data" bash /home/foundry/scripts/backup.sh --restore "$pending_backup" --now --yes
    rm -f "$persistent_data/.restore_pending"
fi

log_step 1 "Server update"
mkdir -p /home/foundry/.steam 2>/dev/null
chmod -R 777 /home/foundry/.steam 2>/dev/null
log_info "Updating Foundry Dedicated Server files..."

if [ ! -z $BETANAME ];then
    if [ ! -z $BETAPASSWORD ]; then
        # Never log the beta password, it is a secret.
        log_info "Using beta $BETANAME with the password ****"
        steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$server_files" +login anonymous +app_update "2915550 -beta $BETANAME -betapassword $BETAPASSWORD" validate +quit
        verify_server_install
    else
        log_info "Using beta $BETANAME without a password!"
        steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$server_files" +login anonymous +app_update "2915550 -beta $BETANAME" validate +quit
        verify_server_install
    fi
else
    log_info "No beta branch used."
    steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$server_files" +login anonymous +app_update 2915550 validate +quit
    verify_server_install
fi

log_info "steam_appid: "`cat $server_files/steam_appid.txt`

log_step 2 "Configuration"
log_info "Checking if app.cfg files exists and no env variables were set"
if [ ! -f "$server_files/app.cfg" ]; then
    log_info "$server_files/app.cfg not found. Copying default file."
    cp "/home/foundry/scripts/app.cfg" "$server_files/" 2>&1
else
    # For the docker image save files to work, the persistent data folder can not be changed in app.cfg
    log_info "Setting persistent data folder in app.cfg for the image to work correctly"
    if grep -q "server_persistent_data_override_folder" $server_files/app.cfg; then
        sed -i "/server_persistent_data_override_folder=/c server_persistent_data_override_folder=/home/foundry/persistent_data" $server_files/app.cfg
    else
        echo -ne '\nserver_persistent_data_override_folder=/home/foundry/persistent_data' >> $server_files/app.cfg
    fi
fi
log_info "Checking if CUSTOM_CONFIG env is set and if set to true:"
if [ ! -z $CUSTOM_CONFIG ]; then
    if [ $CUSTOM_CONFIG = true ];then
	    log_info "Not changing app.cfg file"
	else
	    log_info "Running setup script for the app.cfg file"
            source ./scripts/env2cfg.sh
	fi
    
else
    log_info "Running setup script for the app.cfg file"
    source ./scripts/env2cfg.sh
fi

log_step 3 "Backup scheduler"
# Automatic backups run through an in-process scheduler instead of cron:
# it sees the container environment (BACKUP_RETENTION, TZ), logs to
# `docker logs`, and runs as the foundry user (no root-owned archives).
if [ -n "$NO_CRON" ]; then
    log_info "No-Cron image used! Automatic backups are disabled."
elif [ "$BACKUPS" = false ]; then
    log_warn "[IMPORTANT] Backups are disabled!"
else
    log_info "Starting backup scheduler..."
    bash /home/foundry/scripts/scheduler.sh &
    log_info "Backup scheduler running (pid $!)."
fi

log_step 4 "X11 cleanup"
log_info "Cleaning possible X11 leftovers"
# Clean up X11 lock files and stale socket directories only. /tmp holds other
# runtime data (sockets, temp files of the scheduler and the server itself), so
# it must never be wiped as a whole. Absent files are not an error.
rm -f /tmp/.X*-lock > /dev/null 2>&1
if [ -d /tmp/.X11-unix ]; then
    rm -rf /tmp/.X11-unix/* > /dev/null 2>&1
fi

log_step 5 "Mods"
if [ -d $server_files/Mods ]; then
    log_info "Mods directory already exists, skipping creation."
    else
    mkdir -p $server_files/Mods 2>/dev/null
fi

if [ "$ENABLE_MODS" = true ]; then
    log_info "Download mods..."
    source ./scripts/download_mods.sh
fi

log_step 6 "Launch"
cd "$server_files"
log_info "Starting Foundry Dedicated Server"
log_info "Launching wine Foundry"
source /home/foundry/scripts/wrapper.sh
