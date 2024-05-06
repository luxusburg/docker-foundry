#!/bin/bash
# Location of server data and save data for docker

server_files=/mnt/foundry/server
persistent_data=/mnt/foundry/persistentdata

echo "Setting time zone to $TZ"
echo $TZ > /etc/timezone 2>&1
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime 2>&1
dpkg-reconfigure -f noninteractive tzdata 2>&1

mkdir -p /root/.steam 2>/dev/null
chmod -R 777 /root/.steam 2>/dev/null
echo " "
echo "Updating Foundry Dedicated Server files..."
echo " "
/usr/bin/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$server_files" +login anonymous +app_update 2915550 validate +quit
echo "steam_appid: "`cat $server_files/steam_appid.txt`
echo " "
echo "Checking if app.cfg files exists and no env virables were set"
if [ ! -f "$server_files/app.cfg" ]; then
    echo "$server_files/app.cfg not found. Copying default file."
    cp "/home/steam/app.cfg" "$server_files/" 2>&1
fi

echo "Checking if CUSTOM_CONFIG env is set:"
if [ ! -z $CUSTOM_CONFIG ]; then
    echo "Not changing app.cfg file"
else
    echo "Running setup script for the app.cfg file"
    source ./env2cfg.sh
fi

cd "$server_files"
echo "Starting Foundry Dedicated Server"
echo " "
echo "Starting Xvfb"
Xvfb :0 -screen 0 640x480x24:32 &
echo "Launching wine Foundry"
echo " "
DISPLAY=:0.0 wine /mnt/foundry/server/FoundryDedicatedServer.exe -log 2>&1
