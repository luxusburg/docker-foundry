#!/bin/bash

# To be able to use the volumes user foundry needs access
doas -u root chown -R foundry:foundry /home/foundry
exec "$@"
