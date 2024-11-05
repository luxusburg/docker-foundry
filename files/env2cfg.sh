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
        if grep -q "$config_name" "$APP_FILE"; then
            sed -i "/$config_name=/c $config_name=${!var_name,,}" "$APP_FILE"
        else
            echo -ne "\n$config_name=${!var_name,,}" >> "$APP_FILE"
        fi
    fi
done
