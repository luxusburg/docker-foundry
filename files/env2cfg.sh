#!/bin/bash

# Convert all environment variables to lowercase and export them
for var in $(compgen -e); do export "${var,,}"="${!var}"; done

# Define the app.cfg file path
APP_FILE="$server_files/app.cfg"

# Print a message indicating the script is preparing the app.cfg file
echo "Preparing the app.cfg file"

# Create a backup of the app.cfg file, redirecting any error messages to /dev/null
cp "$server_files/app.cfg" "$server_files/app_backup.cfg" &>/dev/null

# Initialize an empty array to store the set variables
declare -a set_variables

# Loop through the list of environment variables to add to the app.cfg file
for var in world_name server_pwd pause_server_when_empty autosave_interval server_is_public server_port server_query_port map_seed server_name server_max_players max_transfer_rate; do
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

    # Add the set variable to the array
    set_variables+=("$var=$value")
  fi
done

# Print a message indicating the script is done preparing the app.cfg file
echo "Done preparing the app.cfg file."

# Print a message indicating the script is going to display the set variables
echo "Displaying set variables:"

# Loop through the set variables and print each one
for var in "${set_variables[@]}"; do
  echo "$var"
done
