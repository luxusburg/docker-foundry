# Docker for a Foundry dedicated server
[![Docker Pulls](https://img.shields.io/docker/pulls/luxusburg/docker-foundry)](https://hub.docker.com/r/luxusburg/docker-foundry)

[![Image Size](https://img.shields.io/docker/image-size/luxusburg/docker-foundry/latest)](https://hub.docker.com/r/luxusburg/docker-foundry/tags)

[![Docker Hub](https://img.shields.io/badge/Docker_Hub-foundry-blue?logo=docker)](https://hub.docker.com/r/luxusburg/docker-foundry)

This is a Docker container to help you get started with hosting your own [Foundry](https://www.paradoxinteractive.com/games/foundry/about) dedicated server.

This Docker container has been tested and will work on the following OS:

- Linux (Ubuntu/Debian)

This is my first Docker image ever created I am always open to improving it! 

> [!TIP]
> Don't forget to change the values in ./server/app.cfg file that's where you can change the password of the server
> [Link](https://dedicated.foundry-game.com/) from the devs what you can change in that file

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
    -v ./server:/mnt/foundry/server \
    -v ./data:/mnt/foundry/persistentdata \
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
      - './server:/mnt/foundry/server:rw'
      - './data:/mnt/foundry/persistentdata:rw'
    ports:
      - '3724:3724/udp'
      - '27015:27015/udp'
```

## Environment variables

You can use these environment variables for your docker container:

| Variable | Key | Description |
| -------------------- | ---------------------------- | ------------------------------------------------------------------------------- |
| TZ | Europe/Paris | timezone |
| WORLD_NAME | optional save name for map | Sets the server world name. This is the folder where the save files will be stored. |
| SERVER_PWD | optional password | Sets the server password. |
| PAUSE_SERVER_WHEN_EMPTY | optional : true or false  | Will the server pause when nobody is connected. |
| AUTOSAVE_INTERVAL | optional in seconds | Sets the autosave frequency in seconds. |
| SERVER_IS_PUBLIC | optional: true of false | Sets whether the server is listed on the Steam server browser. |
| SERVER_PORT | optional | Sets the network port used by the game. Default is 3724. |
| SERVER_QUERY_PORT | optional | Sets the network port used by the Steam server browser to query information about the game. This is only used if the server is set to public. Default is 27015. |
| SERVER_NAME | optional | This is the name of the server listed in the Steam server browser. |
| MAP_SEED | optional | Sets the map seed used to generate the world. |
| SERVER_MAX_PLAYERS | optional | This sets the max amount of players on a server. |
| CUSTOM_CONFIG | optional: true of false | Set this to true if the server should only accept you manual adapted app.cfg file |
