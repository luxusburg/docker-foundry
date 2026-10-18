#!/bin/bash

APP_FILE="$server_files/app.cfg"

# Migration for issue #33: the game's option is 'mapseed' (no underscore);
# older images wrote 'map_seed', which the server silently ignored. Rename a
# legacy line in-place so hand-set seeds survive, then env2cfg rewrites it
# from the MAP_SEED variable below.
if grep -q '^map_seed=' "$APP_FILE" 2>/dev/null && ! grep -q '^mapseed=' "$APP_FILE"; then
    CFG_LEGACY=map_seed CFG_NEW=mapseed awk '{
        if ($0 ~ ("^" ENVIRON["CFG_LEGACY"] "=")) {
            sub("^" ENVIRON["CFG_LEGACY"] "=", ENVIRON["CFG_NEW"] "=")
        }
        print
    }' "$APP_FILE" > "${APP_FILE}.tmp" && cat "${APP_FILE}.tmp" > "$APP_FILE"
    rm -f "${APP_FILE}.tmp"
fi

variables=( 
    "WORLD_NAME" "server_world_name"
    "SERVER_PWD" "server_password"
    "PAUSE_SERVER_WHEN_EMPTY" "pause_server_when_empty"
    "AUTOSAVE_INTERVAL" "autosave_interval"
    "SERVER_IS_PUBLIC" "server_is_public"
    "SERVER_PORT" "server_port"
    "SERVER_QUERY_PORT" "server_query_port"
    "MAP_SEED" "mapseed"
    "SERVER_NAME" "server_name"
    "SERVER_MAX_PLAYERS" "server_max_players"
    "MAX_TRANSFER_RATE" "max_transfer_rate"
)

# Only booleans and numbers are lowercased. Everything that ends up as a path,
# folder name, seed or display name must keep its exact case.
lowercase_vars=(
    "PAUSE_SERVER_WHEN_EMPTY"
    "AUTOSAVE_INTERVAL"
    "SERVER_IS_PUBLIC"
    "SERVER_PORT"
    "SERVER_QUERY_PORT"
    "SERVER_MAX_PLAYERS"
    "MAX_TRANSFER_RATE"
)

should_lowercase() {
    local candidate
    for candidate in "${lowercase_vars[@]}"; do
        if [ "$candidate" = "$1" ]; then
            return 0
        fi
    done
    return 1
}

for ((i=0; i<${#variables[@]}; i+=2)); do
    var_name=${variables[$i]}
    config_name=${variables[$i+1]}

    if [ ! -z "${!var_name}" ]; then
        echo "${config_name} set to: ${!var_name}"
        if should_lowercase "$var_name"; then
            # Booleans and numbers: safe to lowercase
            value="${!var_name,,}"
        else
            # SERVER_PWD, SERVER_NAME, WORLD_NAME and MAP_SEED are
            # case-sensitive: keep the value exactly as it was given
            value="${!var_name}"
        fi
        if grep -q "^${config_name}=" "$APP_FILE"; then
            # Rewrite the value with awk instead of sed: the value is passed
            # through the environment, so / & | " ' and backslashes stay intact.
            CFG_KEY="$config_name" CFG_VALUE="$value" awk '{
                if ($0 ~ ("^" ENVIRON["CFG_KEY"] "=")) {
                    print ENVIRON["CFG_KEY"] "=" ENVIRON["CFG_VALUE"]
                } else {
                    print
                }
            }' "$APP_FILE" > "${APP_FILE}.tmp" && cat "${APP_FILE}.tmp" > "$APP_FILE"
            rm -f "${APP_FILE}.tmp"
        else
            echo -ne "\n$config_name=$value" >> "$APP_FILE"
        fi
    fi
done
