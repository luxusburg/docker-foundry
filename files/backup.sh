#!/bin/bash
# Backup for the game save files.

# Location of save directory.
loc_dir="/home/foundry/persistent_data/"
# Location of backup folder.
backup_folder="/home/foundry/persistent_data/backup"
# Setting backup retention to a default value when it is not set
if [ -z $BACKUP_RETENTION ]; then
    BACKUP_RETENTION=10
else
    # Checking if backup retention is a number and not negative	
    if [ $BACKUP_RETENTION -gt 0 ] && [[ $BACKUP_RETENTION =~ ^[0-9]+$ ]]; then
        echo "Backup retention value: $BACKUP_RETENTION is valid!"	
    else
        echo "[WARNING] '$BACKUP_RETENTION' is not a valid value! Setting to default!"
        BACKUP_RETENTION=10
    fi
fi

# Checking if backup folder exists.
echo "Checking if backup folder exists:" 
if [ -d $backup_folder ]; then
    echo "$backup_folder exists."
else
    echo "$backup_folder doesn't exists, creating folder!"
    mkdir -p $backup_folder
fi

# Create archive filename.
date=$(date '+%Y-%m-%d_%H-%M-%S')
echo " Creating new archive filename : $date"
archive_file="foundry_backup-$date.tar.gz"

#Backup files
echo "Backing up current save files to $backup_folder/$archive_file"
date
echo " "

tar -czvf $backup_folder/$archive_file -C $loc_dir save/ continue_game.json

echo " "
echo "Backup finished"
echo " "
date

# Keeping only the last $BACKUP_RETENTION backups
echo " "
echo "Keeping only the last $BACKUP_RETENTION backups"
echo " "

# Get list of backups sorted by modification time (oldest first)
backups=($(find $backup_folder -name 'foundry_backup-*' -type f -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-))

# Calculate how many to delete
total_backups=${#backups[@]}
if [ $total_backups -gt $BACKUP_RETENTION ]; then
    delete_count=$((total_backups - BACKUP_RETENTION))
    echo "Found $total_backups backups. Deleting the oldest $delete_count..."
    
    # Delete oldest backups
    for ((i=0; i<delete_count; i++)); do
        echo "Deleting ${backups[i]}"
        rm -f "${backups[i]}"
    done
else
    echo "Found $total_backups backups. No need to delete any (retention is $BACKUP_RETENTION)."
fi

# List of all remaining backups in $backup_folder
echo " "
echo "Current backups:"
ls -lh $backup_folder
