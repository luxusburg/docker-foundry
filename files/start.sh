#!/bin/bash
s=/mnt/foundry/server
p=/mnt/foundry/persistentdata
echo "Setting timezone to $TZ"
echo $TZ > /etc/timezone 2>&1
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime 2>&1
dpkg-reconfigure -f noninteractive tzdata 2>&1

mkdir -p /root/.steam 2>/dev/null
chmod -R 777 /root/.steam 2>/dev/null
echo " "
echo "Updating Foundry Dedicated Server files..."
echo " "
/usr/bin/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$s" +login anonymous +app_update 2915550 validate +quit
echo "steam_appid: "`cat $s/steam_appid.txt`
echo " "
echo "Checking if app.cfg files exists"
if [ ! -f "$s/app.cfg" ]; then
        echo "$s/app.cfg not found. Copying default file."
        cp "/home/steam/app.cfg" "$p/" 2>&1
fi
cd "$s"
echo "Starting Foundry Dedicated Server"
echo " "
echo "Starting Xvfb"
Xvfb :0 -screen 0 1024x768x16 &
echo "Launching wine Foundry"
echo " "
DISPLAY=:0.0 wine /mnt/foundry/server/FoundryDedicatedServer.exe -log 2>&1
