# Docker for a Foundry dedicated server
[![Docker Pulls](https://img.shields.io/docker/pulls/luxusburg/docker-foundry)](https://hub.docker.com/r/luxusburg/docker-foundry)

[![Image Size](https://img.shields.io/docker/image-size/luxusburg/docker-foundry/latest)](https://hub.docker.com/r/luxusburg/docker-foundry/tags)

[![Docker Hub](https://img.shields.io/badge/Docker_Hub-foundry-blue?logo=docker)](https://hub.docker.com/r/luxusburg/docker-foundry)

This is a Docker container to help you get started with hosting your own [Foundry](https://www.paradoxinteractive.com/games/foundry/about) dedicated server.

This Docker container has been tested and will work on the following OS:

- Linux (Ubuntu/Debian)

This is my first Docker image ever created I am always open to improving it! 

> [!TIP]
> Add environment variables so that you can for example change the password of the server
> On the bottom you will find a list of all environment variables to change, if you want to use your own app.cfg file
> set the CUSTOM_CONFIG to true
> Here are all the possible changes from the devs [link](https://dedicated.foundry-game.com/) 

## Docker Run

**This will create the folders './server' and './data' in your current folder where you execute the code**

**Recommendation:**
Create a folder before executing this docker command

To deploy this docker project run:

```bash
docker run -d \
    --name foundry \
    -p 3724:3724/udp \    
    -p 27015:27015/udp \
    -v ./server:/home/foundry/server_files \
    -v ./data:/home/foundry/persistent_data \
    -e TZ=Europe/Paris \
    -e SERVER_PWD=change_me
    -e SERVER_NAME='Foundry docker by Luxusburg'
    -e PAUSE_SERVER_WHEN_EMPTY=false
    luxusburg/docker-foundry:latest
```

## Docker compose Deployment

**This will create the folders './server' and './data' in your current folder where you execute combose file**

**Recommendation:**
Create a folder before executing the docker compose file

> [!IMPORTANT]
> Older docker compose version needs this line before the **services:** line
>
> version: '3'

```yml
services:
  foundry:
    container_name: foundry
    image: luxusburg/docker-foundry:latest
    network_mode: bridge
    environment:
      - TZ=Europe/Paris
      - SERVER_PWD=change_me
      - SERVER_NAME='Foundry docker by Luxusburg'
      - PAUSE_SERVER_WHEN_EMPTY=false
    volumes:
      - './server:/home/foundry/server_files_:rw'
      - './data:/home/foundry/persistent_data:rw'
    ports:
      - '3724:3724/udp'
      - '27015:27015/udp'
    restart: unless-stopped
```

## Backup & recovery

Backups are all saved in the folder you set in your volume for `/location/of/folder:/mnt/foundry/persistentdata`
There should be a folder in it called `backup`.

Per Default backups are activated and done every hour of the day you can change this by looking at the environment variables further below.

> [!IMPORTANT]
> This command will overwrite your current save files! **Copy/backup the files before overwriting them!**

If you want to recover a backup you need to stop the container and unzip the files into your folder `/location/of/folder` with this command for example
`tar -xzvf /location/of/folder/backup/foundry-backup-DATE_AND_TIME_OF_BACKUP_YOU_WANT_TO_USE.tar.gz -C /location/of/folder/`


## Environment variables Game settings

You can use these environment variables for your game settings:

| Variable | Key | Description |
| -------------------- | ---------------------------- | ------------------------------------------------------------------------------- |
| TZ | Europe/Paris | timezone |
| WORLD_NAME | optional save name for map | Sets the server world name. This is the folder where the save files will be stored. |
| SERVER_PWD | optional password | Sets the server password. |
| PAUSE_SERVER_WHEN_EMPTY | optional: true or false  | Will the server pause when nobody is connected. |
| AUTOSAVE_INTERVAL | optional in seconds | Sets the autosave frequency in seconds. |
| SERVER_IS_PUBLIC | optional: true of false | Sets whether the server is listed on the Steam server browser. |
| SERVER_PORT | optional | Sets the network port used by the game. Default is 3724. |
| SERVER_QUERY_PORT | optional | Sets the network port used by the Steam server browser to query information about the game. This is only used if the server is set to public. Default is 27015. |
| SERVER_NAME | optional | This is the name of the server listed in the Steam server browser. |
| MAP_SEED | optional | Sets the map seed used to generate the world. |
| SERVER_MAX_PLAYERS | optional | This sets the max amount of players on a server. |
| MAX_TRANSFER_RATE | optional default: 1024 max: 8192 | Change transfer rate of the server data |
| CUSTOM_CONFIG | optional: true of false | Set this to true if the server should only accept you manual adapted app.cfg file |

## Environment variables Backup settings

> [!WARNING]
> For BACKUP_INTERVAL **do not set double or single quotes** :  `""` or `''`

| Variable | Key | Description |
| -------------------- | ---------------------------- | ------------------------------------------------------------------------------- |
| BACKUPS | true (default) or false | Activate backups |
| BACKUP_INTERVAL | default: 0 * * * * | [Cron schedule](https://en.wikipedia.org/wiki/Cron#Overview) value for the backups |
| BACKUP_RETENTION | default: 30 min: 1 |Sets how many days the backups should be kept |

## Environment variables for the User PUID/GUID

| Variable | Key | Description |
| -------------------- | ---------------------------- | ------------------------------------------------------------------------------- |
| PUID | default: 1000 | User ID |
| PGUID | default: 1000| Group ID |
