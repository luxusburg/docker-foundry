#!/bin/bash

APP_FILE="$server_files/app.cfg"

echo "Preparing the app.cfg file"

cp "$server_files/app.cfg" "$server_files/app_backup.cfg" &>/dev/null

for var in WORLD_NAME SERVER_PWD PAUSE_SERVER_WHEN_EMPTY AUTOSAVE_INTERVAL SERVER_IS_PUBLIC SERVER_PORT SERVER_QUERY_PORT MAP_SEED SERVER_NAME SERVER_MAX_PLAYERS MAX_TRANSFER_RATE; do
  if [[ -n ${!var} ]]; then
    value=${!var}
    if grep -q "^${var}=" "$APP_FILE"; then
      sed -i "s/^${var}=.*/${var}=${value}/" "$APP_FILE"
    else
      echo "${var}=${value}" >> "$APP_FILE"
    fi
  fi
done
