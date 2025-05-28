#!/bin/bash

APP_FILE="$server_files/app.cfg"

variables=( 
    "WORLD_NAME" "server_world_name"
    "SERVER_PWD" "server_password"
    "PAUSE_SERVER_WHEN_EMPTY" "pause_server_when_empty"
    "AUTOSAVE_INTERVAL" "autosave_interval"
    "SERVER_IS_PUBLIC" "server_is_public"
    "SERVER_PORT" "server_port"
    "SERVER_QUERY_PORT" "server_query_port"
    "MAP_SEED" "map_seed"
    "SERVER_NAME" "server_name"
    "SERVER_MAX_PLAYERS" "server_max_players"
    "MAX_TRANSFER_RATE" "max_transfer_rate"
)

for ((i=0; i<${#variables[@]}; i+=2)); do
    var_name=${variables[$i]}
    config_name=${variables[$i+1]}

    if [ ! -z "${!var_name}" ]; then
        echo "${config_name} set to: ${!var_name}"
        # Check if this is SERVER_PWD or SERVER_NAME
        if [[ "$var_name" == "SERVER_PWD" || "$var_name" == "SERVER_NAME" ]]; then
            # Don't convert to lowercase for these variables
            value="${!var_name}"
        else
            # Convert to lowercase for other variables
            value="${!var_name,,}"
        fi
        if grep -q "$config_name" "$APP_FILE"; then
            sed -i "/$config_name=/c $config_name=$value" "$APP_FILE"
        else
            echo -ne "\n$config_name=$value" >> "$APP_FILE"
        fi
    fi
done
