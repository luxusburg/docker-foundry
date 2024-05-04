# Docker for an Foundry dedicated server
[![Docker Pulls](https://img.shields.io/docker/pulls/luxusburg/docker-foundry)](https://hub.docker.com/r/luxusburg/docker-foundry)

[![Image Size](https://img.shields.io/docker/image-size/luxusburg/docker-foundry/latest)](https://hub.docker.com/r/luxusburg/docker-foundry/tags)

[![Docker Hub](https://img.shields.io/badge/Docker_Hub-foundry-blue?logo=docker)](https://hub.docker.com/r/luxusburg/docker-foundry)

This is a Docker container to help you get started with hosting your own [Foundry](https://www.paradoxinteractive.com/games/foundry/about) dedicated server.

This Docker container has been tested and will work on the following OS:

- Linux (Ubuntu/Debian)

> [!IMPORTANT]
> On Steam Deck the game crashes or immidiatly discconects after connecting to the server
>
>Could also be for all Proton players?

This is my first Docker image ever created I am always open for improving it! 
## Docker Run

**This will create the folders './server' and './data' in your current folder where you execute the code**

**Recommandation:**
Create a folder before executing this docker command

To deploy this docker project run:

```bash
docker run -d \
    --name foundry \
    -p 3724:3724/upd \    
    -p 27015:27015/udp \
    -v ./server:/mnt/foundry/server \
    -v ./data:/mnt/foundry/persistentdata \
    -e TZ=Europe/Paris \
    luxusburg/docker-foundry:latest
```

## Docker combose Deployment

**This will create the folders './server' and './data' in your current folder where you execute combose file**

**Recommandation:**
Create a folder before executing the docker combose file

```yml
services:
  foundry:
    container_name: foundry
    image: luxusburg/docker-foundry:latest
    network_mode: bridge
    environment:
      - TZ=Europe/Paris
    volumes:
      - './server:/mnt/foundry/server:rw'
      - './data:/mnt/foundry/persistentdata:rw'
    ports:
      - '3724:3724/udp'
      - '27015:27015/udp
```
