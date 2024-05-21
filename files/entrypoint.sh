#!/bin/bash

# To be able to use the volumes user foundry needs access
doas -u root chown -R foundry:foundry /home/foundry
# Set the timezone for the root user
does -u root export TZ=${TZ:-'Europe/Berlin'}
exec "$@"
