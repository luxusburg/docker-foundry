#!/bin/bash
# Location of server data and save data for docker

# Check if old volume mounts exists from before 1.3 # we check for 2 but only warned about 1
if [ -d '/mnt/foundry/server' ] || [ -d '/mnt/foundry/persistentdata' ]; then
    echo "Old docker volume setup found!"
    echo "Change your volume from /your/path/:/mnt/foundry/server to /your/path/:/home/foundry/server_files"
    echo "Change your volume from /your/path/:/mnt/foundry/persistentdata to /your/path/:/home/foundry/persistent_data"
    echo "Check release notes 1.3 for more information!"
    echo "https://github.com/luxusburg/docker-foundry/releases"
    exit 1
fi

server_files=/home/foundry/server_files
persistent_data=/home/foundry/persistent_data

echo " "
echo "Server files location is set to : $server_files"
echo "Save files location is set to : $persistent_data"
echo " "

# Aborts the boot if the steamcmd download did not produce a usable server.
verify_server_install() {
    if [ ! -f "$server_files/FoundryDedicatedServer.exe" ]; then
        echo '[ERROR] Foundry server installation failed - FoundryDedicatedServer.exe missing' >&2
        exit 1
    fi
}

# Apply a deferred restore (backup.sh --restore without --now) before the
# server starts, so the game loads the restored save.
if [ -f "$persistent_data/.restore_pending" ]; then
    pending_backup=$(cat "$persistent_data/.restore_pending")
    echo "Pending restore found: $pending_backup"
    PERSISTENT_DATA="$persistent_data" bash /home/foundry/scripts/backup.sh --restore "$pending_backup" --now --yes
    rm -f "$persistent_data/.restore_pending"
fi

mkdir -p /home/foundry/.steam 2>/dev/null
chmod -R 777 /home/foundry/.steam 2>/dev/null
echo " "
echo "Updating Foundry Dedicated Server files..."
echo " "

if [ ! -z $BETANAME ];then
    if [ ! -z $BETAPASSWORD ]; then
        # Never log the beta password, it is a secret.
        echo "Using beta $BETANAME with the password ****"
        steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$server_files" +login anonymous +app_update "2915550 -beta $BETANAME -betapassword $BETAPASSWORD" validate +quit
        verify_server_install
    else
        echo "Using beta $BETANAME without a password!"
        steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$server_files" +login anonymous +app_update "2915550 -beta $BETANAME" validate +quit
        verify_server_install
    fi
else
    echo "No beta branch used."
    steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$server_files" +login anonymous +app_update 2915550 validate +quit
    verify_server_install
fi

echo "steam_appid: "`cat $server_files/steam_appid.txt`
echo " "

echo "Checking if app.cfg files exists and no env variables were set"
if [ ! -f "$server_files/app.cfg" ]; then
    echo "$server_files/app.cfg not found. Copying default file."
    cp "/home/foundry/scripts/app.cfg" "$server_files/" 2>&1
else
    # For the docker image save files to work, the persistent data folder can not be changed in app.cfg
    echo "Setting persistent data folder in app.cfg for the image to work correctly"
    if grep -q "server_persistent_data_override_folder" $server_files/app.cfg; then
        sed -i "/server_persistent_data_override_folder=/c server_persistent_data_override_folder=/home/foundry/persistent_data" $server_files/app.cfg
    else
        echo -ne '\nserver_persistent_data_override_folder=/home/foundry/persistent_data' >> $server_files/app.cfg
    fi
fi
echo " "

echo "Checking if CUSTOM_CONFIG env is set and if set to true:"
if [ ! -z $CUSTOM_CONFIG ]; then
    if [ $CUSTOM_CONFIG = true ];then
	    echo "Not changing app.cfg file"
	else
	    echo "Running setup script for the app.cfg file"
            source ./scripts/env2cfg.sh
	fi
    
else
    echo "Running setup script for the app.cfg file"
    source ./scripts/env2cfg.sh
fi

echo " "
# Automatic backups run through an in-process scheduler instead of cron:
# it sees the container environment (BACKUP_RETENTION, TZ), logs to
# `docker logs`, and runs as the foundry user (no root-owned archives).
if [ -n "$NO_CRON" ]; then
    echo "No-Cron image used! Automatic backups are disabled."
elif [ "$BACKUPS" = false ]; then
    echo "[IMPORTANT] Backups are disabled!"
else
    echo "Starting backup scheduler..."
    bash /home/foundry/scripts/scheduler.sh &
    echo "Backup scheduler running (pid $!)."
fi

echo " "
echo "Cleaning possible X11 leftovers"
echo " "
# Clean up X11 lock files and stale socket directories only. /tmp holds other
# runtime data (sockets, temp files of the scheduler and the server itself), so
# it must never be wiped as a whole. Absent files are not an error.
rm -f /tmp/.X*-lock > /dev/null 2>&1
if [ -d /tmp/.X11-unix ]; then
    rm -rf /tmp/.X11-unix/* > /dev/null 2>&1
fi

if [ -d $server_files/Mods ]; then
    echo "Mods directory already exists, skipping creation."
    else
    mkdir -p $server_files/Mods 2>/dev/null
fi

if [ "$ENABLE_MODS" = true ]; then
    echo "Download mods..."
    source ./scripts/download_mods.sh
fi

cd "$server_files"
echo "Starting Foundry Dedicated Server"
echo " "
echo "Launching wine Foundry"
echo " "
source /home/foundry/scripts/wrapper.sh
