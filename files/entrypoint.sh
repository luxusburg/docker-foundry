#!/bin/bash

# Apply PUID/PGID at runtime so files written to the mounted volumes are
# owned by the user/group the host expects. Defaults to 1000:1000.
PUID=${PUID:-1000}
PGID=${PGID:-1000}

current_uid=$(id -u foundry)
current_gid=$(getent group foundry | cut -d: -f3)

if [ "$PGID" != "$current_gid" ]; then
    echo "Updating foundry group id: $current_gid -> $PGID"
    sudo groupmod -o -g "$PGID" foundry
fi

if [ "$PUID" != "$current_uid" ]; then
    echo "Updating foundry user id: $current_uid -> $PUID"
    sudo usermod -o -u "$PUID" foundry
fi

# To be able to use the volumes user foundry needs access
sudo chown -R foundry:foundry /home/foundry

# If the IDs were remapped, the current process still runs under the old UID,
# so re-exec the command as the updated foundry user.
if [ "$PUID" != "$current_uid" ] || [ "$PGID" != "$current_gid" ]; then
    exec sudo -E -u foundry "$@"
else
    exec "$@"
fi
