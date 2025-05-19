#!/bin/bash

# To be able to use the volumes user foundry needs access
sudo -u root chown -R foundry:foundry /home/foundry
exec "$@"
