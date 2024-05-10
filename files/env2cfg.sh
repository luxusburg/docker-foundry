#!/bin/bash
# Default location of app.cfg file
APP_FILE="$server_files/app.cfg"

echo "Preparing the app.cfg file"

# Backup app.cfg file if it exists
if [ -f "$server_files/app.cfg" ]; then
        cp "$server_files/app.cfg" "$server_files/app_backup.cfg"
fi

# Insert environment variables into the app.cfg file
if [ ! -z $WORLD_NAME ]; then
    echo "World name changed to: $WORLD_NAME"
	if grep -q "server_world_name" $APP_FILE; then
        sed -i '/server_world_name=/c server_world_name='$WORLD_NAME $APP_FILE
	else
	    echo -ne '\nserver_world_name='$WORLD_NAME >> $APP_FILE
	fi
fi

if [ -z $SERVER_PWD ]; then
    echo "[INFO] No password set!"
else
    if grep -q "server_password" $APP_FILE; then
        sed -i '/server_password=/c server_password='$SERVER_PWD $APP_FILE
	else
	    echo -ne '\nserver_password='$SERVER_PWD >> $APP_FILE
	fi
	echo "Server password set!"
fi

if [ ! -z $PAUSE_SERVER_WHEN_EMPTY ]; then
    echo "Pause server when empty set to: $PAUSE_SERVER_WHEN_EMPTY"
    if grep -q "pause_server_when_empty" $APP_FILE; then
	    sed -i '/pause_server_when_empty=/c pause_server_when_empty='$PAUSE_SERVER_WHEN_EMPTY $APP_FILE
	else
	    echo -ne '\npause_server_when_empty='$PAUSE_SERVER_WHEN_EMPTY >> $APP_FILE
	fi
fi

if [ ! -z $AUTOSAVE_INTERVAL ]; then
    echo "Autosave interval set to: $AUTOSAVE_INTERVAL"
	if grep -q "autosave_interval" $APP_FILE; then
	    sed -i '/autosave_interval=/c autosave_interval='$AUTOSAVE_INTERVAL $APP_FILE
	else
	    echo -ne '\nautosave_interval='$AUTOSAVE_INTERVAL >> $APP_FILE
	fi	
fi

if [ ! -z $SERVER_IS_PUBLIC ]; then
    echo "Server is public set to: $SERVER_IS_PUBLIC"
	if grep -q "server_is_public" $APP_FILE; then
	    sed -i '/server_is_public=/c server_is_public='$SERVER_IS_PUBLIC $APP_FILE
	else
	    echo -ne '\nserver_is_public='$SERVER_IS_PUBLIC >> $APP_FILE
	fi	
fi

if [ ! -z $SERVER_PORT ]; then
    echo "Server port set to: $SERVER_PORT"
	if grep -q "server_port" $APP_FILE; then
	    sed -i '/server_port=/c server_port='$SERVER_PORT $APP_FILE
	else
	    echo -ne '\nserver_port='$SERVER_PORT >> $APP_FILE
	fi	
fi

if [ ! -z $SERVER_QUERY_PORT ]; then
    echo "Server query port set to: $SERVER_QUERY_PORT"
	if grep -q "server_query_port" $APP_FILE; then
	    sed -i '/server_query_port=/c server_query_port='$SERVER_QUERY_PORT $APP_FILE
	else
	    echo -ne '\nserver_query_port='$SERVER_QUERY_PORT >> $APP_FILE
	fi	
fi


if [ ! -z $MAP_SEED ]; then
    echo "Changed map seed to: $MAP_SEED"
	if grep -q "map_seed" $APP_FILE; then
	    sed -i '/map_seed=/c map_seed='$MAP_SEED $APP_FILE
	else
	    echo -ne '\nmap_seed='$MAP_SEED >> $APP_FILE
	fi	
fi

if [ ! -z $SERVER_NAME ]; then
    echo "Server name set to: $SERVER_NAME"
	if grep -q "server_name" $APP_FILE; then
	    sed -i '/server_name=/c server_name='$SERVER_NAME $APP_FILE
	else
	    echo -ne '\nserver_name='$SERVER_NAME >> $APP_FILE
	fi	
fi

if [ ! -z $SERVER_MAX_PLAYERS ]; then
    echo "Server max players set to: $SERVER_MAX_PLAYERS"
	if grep -q "server_max_players" $APP_FILE; then
	    sed -i '/server_max_players=/c server_max_players='$SERVER_MAX_PLAYERS $APP_FILE
	else
	    echo -ne '\nserver_max_players='$SERVER_MAX_PLAYERSg >> $APP_FILE
	fi	
fi

if [ ! -z $MAX_TRANSFER_RATE ] ; then
    echo "Server max transfer rate set to: $MAX_TRANSFER_RATE"
	if grep -q "max_transfer_rate" $APP_FILE; then
	    sed -i '/max_transfer_rate=/c max_transfer_rate='$MAX_TRANSFER_RATE $APP_FILE
	else
	    echo -ne '\nmax_transfer_rate='$MAX_TRANSFER_RATE >> $APP_FILE
	fi
fi 