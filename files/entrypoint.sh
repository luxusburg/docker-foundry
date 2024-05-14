#!/bin/bash

# To be able to use the volumes user foundry needs access
chown -R foundry:foundry /home/foundry
chown -R foundry:foundry /tmp
chown -R foundry:foundry /var/spool/cron/crontabs/root
exec runuser -u foundry "$@"
