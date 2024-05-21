#!/bin/bash
# Location of server data and save data for docker

server_files=/home/foundry/server_files
persistent_data=/home/foundry/persistent_data

echo " "
echo "Server files location is set to : $server_files"
echo "Save files locaiton is set to : $persistent_data"
echo " "

mkdir -p /home/foundry/.steam 2>/dev/null
chmod -R 777 /home/foundry/.steam 2>/dev/null
echo " "
echo "Updating Foundry Dedicated Server files..."
echo " "
steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$server_files" +login anonymous +app_update 2915550 validate +quit
echo "steam_appid: "`cat $server_files/steam_appid.txt`
echo " "

echo "Checking if app.cfg files exists and no env virables were set"
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
if [ ! -z $NO_CRON ]; then
    echo "No Cron image used!"
else
    # Starting crond to be sure it's running
    doas -u root crond
    if []
    if [ ! -z $BACKUPS ]; then
        if [ $BACKUPS = false ]; then
            echo "[IMPORTANT] Backups are disabled!"
            doas -u root sed -i "/backup.sh/c # 0 * * * * /home/foundry/scripts/backup.sh 2>&1" /var/spool/cron/crontabs/root
            echo " "
        fi
    fi
    if [ ! -z "$BACKUP_INTERVAL" ]; then
        if [[ $BACKUPS = false ]]; then
            echo "[IMPORTANT] Backups are disabled ignoring BACKUP_INTERVAL!"
        else
            echo "Changing backup interval to $BACKUP_INTERVAL"
             doas -u root sed -i "/backup.sh/c $BACKUP_INTERVAL /home/foundry/scripts/backup.sh 2>&1" /var/spool/cron/crontabs/root
            echo " "
        fi    
    fi
fi
echo " "
echo "Cleaning possible X11 leftovers"
echo " "
rm /tmp/.X0-lock
rm -r /tmp/*

# add Mods folder for future use
mkdir -p $server_files/Mods 2>/dev/null

cd "$server_files"
echo "Starting Foundry Dedicated Server"
echo " "
echo "Launching wine Foundry"
echo " "
xvfb-run wine $server_files/FoundryDedicatedServer.exe -log 2>&1
