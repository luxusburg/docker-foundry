#!/bin/bash

# Define the app.cfg file path
APP_FILE="$server_files/app.cfg"

# Print a message indicating the script is preparing the app.cfg file
echo "Preparing the app.cfg file"

# Create a backup of the app.cfg file, redirecting any error messages to /dev/null
cp "$server_files/app.cfg" "$server_files/app_backup.cfg" &>/dev/null

# Loop through the list of environment variables to add to the app.cfg file
for var in WORLD_NAME SERVER_PWD PAUSE_SERVER_WHEN_EMPTY AUTOSAVE_INTERVAL SERVER_IS_PUBLIC SERVER_PORT SERVER_QUERY_PORT MAP_SEED SERVER_NAME SERVER_MAX_PLAYERS MAX_TRANSFER_RATE; do
  # Check if the environment variable is set
  if [[ -n ${!var} ]]; then
    # Assign the value of the environment variable to the variable 'value'
    value=${!var}

    # Check if the variable already exists in the app.cfg file
    if grep -q "^${var}=" "$APP_FILE"; then
      # If the variable exists, replace its value in the app.cfg file
      sed -i "s/^${var}=.*/${var}=${value}/" "$APP_FILE"
    else
      # If the variable doesn't exist, append it to the app.cfg file
      echo "${var}=${value}" >> "$APP_FILE"
    fi
  fi
done
