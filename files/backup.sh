#!/bin/bash
# Backup for the game save files.

# Location of save files.
save_files_to_backup="/mnt/foundry/persistentdata/save/ /mnt/foundry/persistentdata/continue_game.json"
# Location of backup folder.
backup_folder="/mnt/foundry/persistentdata/backup"
# Setting backup retention to a default value when it is not set
if [ -z $BACKUP_RETENTION ]; then
    BACKUP_RETENTION=30
else
    # Checking if backup retention is a number and not negative	
    if [ $BACKUP_RETENTION > 0 ] && [[ $BACKUP_RETENTION =~ ^[0-9]+$ ]]; then
	    echo "Backup retention value: $BACKUP_RETENTION is valid!"	
	else
	    echo "[WARNING] '$BACKUP_RETENTION' is not a valid value! Setting to default!"
	    BACKUP_RETENTION=30
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

tar -czvf $backup_folder/$archive_file $save_files_to_backup

echo " "
echo "Backup finished"
echo " "
date

# Removing files older than $BACKUP_RETENTION days
echo " "
echo "Removing backups older than: $BACKUP_RETENTION days"
echo " "
find $backup_folder -name 'foundry_backup-*' -type f -mtime +$BACKUP_RETENTION -delete

# List of all backups in $backup_folder
ls -lh $backup_folder
