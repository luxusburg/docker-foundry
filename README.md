# Foundry Dedicated Server Docker Container 🏭
[![Docker Hub](https://img.shields.io/badge/Docker_Hub-foundry-blue?logo=docker)](https://hub.docker.com/r/luxusburg/docker-foundry)
[![Docker Pulls](https://img.shields.io/docker/pulls/luxusburg/docker-foundry)](https://hub.docker.com/r/luxusburg/docker-foundry)
[![Image Size](https://img.shields.io/docker/image-size/luxusburg/docker-foundry/latest)](https://hub.docker.com/r/luxusburg/docker-foundry/tags)
[![Github](https://img.shields.io/badge/Github-foundry-blue?logo=github)](https://github.com/luxusburg/docker-foundry)
![GitHub last commit](https://img.shields.io/github/last-commit/luxusburg/docker-foundry)

This Docker container simplifies hosting your own [Foundry](https://www.paradoxinteractive.com/games/foundry/about) dedicated server. 🚀

It has been tested and confirmed to work on Linux (Ubuntu/Debian). 🐧

Contributions and feedback for improvements are welcome! 🤝

## 📜 Table of Contents

- [✨ Features](#-features)
- [✅ Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
  - [🐳 Using `docker run`](#-using-docker-run)
  - [🏗️ Using `docker-compose`](#-using-docker-compose)
- [⚙️ Server Configuration](#-server-configuration)
  - [🗂️ Volumes](#-volumes)
- [💾 Backup and Recovery](#-backup-and-recovery)
- [🧩 Enabling and Managing Mods](#-enabling-and-managing-mods)
- [🔧 Environment Variables](#-environment-variables)
  - [🎮 Game Settings](#-game-settings)
  - [🗳️ Backup Settings](#-backup-settings)
  - [👤 User PUID/PGID](#-user-puidpgid)
  - [🧪 Beta Branch](#-beta-branch)
- [💖 Contributing](#-contributing)

## ✨ Features

* 💨 Easy setup for a Foundry dedicated server.
* 🔄 Automated game server updates on container start.
* 🔧 Configurable via environment variables.
* 💾 Built-in backup and restore functionality.
* 🧩 Mod support.
* 🧪 Support for game beta branches.

## ✅ Prerequisites

* Docker installed on your system.
* Docker Compose (for `docker-compose` method).
* Basic understanding of Docker concepts (volumes, ports).

## 🚀 Quick Start

It's recommended to create a dedicated directory on your host machine to store server data and configuration before running the commands. For example:

```bash
mkdir ~/foundry-server
cd ~/foundry-server
```
The following examples will map `./server` (for game files) and `./data` (for persistent data like saves and backups) in your current working directory to the container.

## 🐳 Using `docker run`
```bash
docker run -d \
    --name foundry-server \
    -p 3724:3724/udp \
    -p 27015:27015/udp \
    -v ./server:/home/foundry/server_files \
    -v ./data:/home/foundry/persistent_data \
    -e TZ="Europe/Paris" \
    -e SERVER_NAME=Foundry Docker by Luxusburg \
    -e SERVER_PWD=change_me \
    -e PAUSE_SERVER_WHEN_EMPTY=false \
    -e MAX_TRANSFER_RATE=8192 \
    luxusburg/docker-foundry:latest
```
## 🏗️ Using `docker-compose`
Create a `docker-compose.yml` file:
```yaml
# version: '3.8' # Uncomment if your Docker Compose version requires it
services:
  foundry:
    container_name: foundry-server
    image: luxusburg/docker-foundry:latest
    network_mode: bridge # Or 'host' if preferred, adjust ports accordingly
    environment:
      - TZ=Europe/Paris
      - WORLD_NAME='worldname'
      - SERVER_PWD=change_me_strong_password
      - SERVER_NAME=Foundry Docker - by Luxusburg
      - SERVER_MAX_PLAYERS=10
      - SERVER_IS_PUBLIC=true
      - PAUSE_SERVER_WHEN_EMPTY=false
      - AUTOSAVE_INTERVAL=300
      - MAX_TRANSFER_RATE=8192
      - CUSTOM_CONFIG=false # Set to true to use a custom app.cfg
      # Backup Settings
      - BACKUPS=true
      - BACKUP_INTERVAL=0 * * * * # Every hour at minute 0
      - BACKUP_RETENTION=3 # Keep backups older than X days
      # Mod Settings
      # - ENABLE_MODS=true # Uncomment to enable mods
      # PUID/PGID Settings
      # - PUID=1000
      # - PGID=1000
    volumes:
      - ./server:/home/foundry/server_files:rw
      - ./data:/home/foundry/persistent_data:rw
    ports:
      - "3724:3724/udp"
      - "27015:27015/udp" # Only needed if SERVER_IS_PUBLIC=true
    restart: unless-stopped
```

Then run:

```bash
docker compose up -d
```

## ⚙️ Server Configuration

### 🗂️ Volumes

- `/home/foundry/server_files` (e.g., `./server` on host): Stores the main game server files installed via SteamCMD, app.cfg and mod data.
- `/home/foundry/persistent_data` (e.g., `./data` on host): Stores world saves and backups.

>[!TIP]
> You can customize server settings by editing the `app.cfg` file located in your server files volume (e.g., `./server/app.cfg`) after the first run.
> Alternatively, use environment variables. For a fully custom `app.cfg`, set `CUSTOM_CONFIG=true` and ensure your `app.cfg is` present in the server files directory.
> Refer to the official developer documentation for all possible `app.cfg` settings: [Foundry Dedicated Server Docs](https://dedicated.foundry-game.com/)

## 💾 Backup and Recovery

Backups are enabled by default and stored in the `backup` subfolder within your persistent data volume (e.g., `./data/backup/`).

**To recover a backup:**

1. Stop the Foundry server container:
```bash
docker stop foundry-server
# or for docker-compose
docker compose down
```
>[!IMPORTANT]
> ❗ The following command will overwrite your current world save files! **Ensure you have a separate copy of your current world data if you might need it.**

2. Extract the desired backup archive into your persistent data directory. Replace `your_persistent_data_path` in our example (e.g., `./data`) and the backup filename accordingly:
```bash
# Example:
tar -xzvf ./data/backup/foundry-backup-YYYY-MM-DD_HH-MM-SS.tar.gz -C ./data/
```
**This will restore the save folder into `./data/`**
3. Restart the container

## 🧩 Enabling and Managing Mods

1. Enable Mod Support

Set the environment variable `ENABLE_MODS=true` in your Docker configuration.

3. Mod List File (**Crucial!**)
- The server requires a `modList.json` file to be present in the `Mods` folder within your server files volume (e.g., `./server/Mods/modList.json`) to start correctly when mods are enabled.
- This file is typically generated by your Foundry game client and contains your subscribed mods and their configurations. You need to copy this file from your client (usually found at `C:\Program Files (x86)\Steam\steamapps\common\FOUNDRY\Mods\modList.json` on Windows) to the server's mod directory.

### Mod Updates
When `ENABLE_MODS=true`, the server will attempt to check for and download/update subscribed mods on each startup. 🔄

### File Locations (relative to your mapped volumes)
- **Mod Storage:** `your_server_files_volume/Mods/` (e.g., `./server/Mods/`)
- **Mod Configuration:** `your_data_volume/mod_settings/` (e.g., ./data/mod_settings/`)

## 🔧 Environment Variables

The container uses environment variables for configuration.

### 🎮 Game Settings

| Variable                  | Default / Example       | Description |
|---------------------------|-------------------------|-------------|
| `TZ`                      | `Europe/Paris`          | Sets the timezone for the container 🌍. [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones). |
| `WORLD_NAME`              | `FoundryDockerWorld`    | Sets the server world name 🗺️. This is the folder name within `FoundryDedicatedServer/Worlds/` where save files will be stored. |
| `SERVER_PWD`              | (none)                  | Sets the server password 🔑. **Highly recommended**. |
| `SERVER_NAME`             | `Foundry Docker Server` | Name of the server listed in the Steam server browser (if public) 📢. |
| `MAP_SEED`                | (game default)          | Sets the map seed used to generate the world 🌱. |
| `SERVER_MAX_PLAYERS`      | `10`                    | Sets the maximum number of players allowed on the server 🧑‍🤝‍🧑. |
| `PAUSE_SERVER_WHEN_EMPTY` | `false`                 | `true` or `false`. Pauses the server when no players are connected ⏸️. |
| `AUTOSAVE_INTERVAL`       | `300`                   | Autosave frequency in seconds ⏱️. |
| `SERVER_IS_PUBLIC`        | `false`                 | `true` or `false`. Sets whether the server is listed on the Steam server browser 🌐. |
| `SERVER_PORT`             | `3724`                  | Network port used by the game 🔌. |
| `SERVER_QUERY_PORT`       | `27015`                 | Network port for Steam server browser queries (used if `SERVER_IS_PUBLIC=true`) 📡. |
| `MAX_TRANSFER_RATE`       | `1024` (KiB/s)          | Maximum data transfer rate for clients 📶. **Max:** `8192`. |
| `CUSTOM_CONFIG`           | `false`                 | Set to `true` if you want the server to exclusively use a manually provided `app.cfg` file (located in persistent data) 📝. |

### 🗳️ Backup Settings

> [!WARNING]  
> For `BACKUP_INTERVAL`, do not use double (`""`) or single (`''`) quotes around the cron schedule value.

| Variable          | Default / Example      | Description |
|-------------------|------------------------|-------------|
| `BACKUPS`         | `true`                 | `true` or `false`. Enables or disables the automatic backup system. |
| `BACKUP_INTERVAL` | `0 * * * *`            | Cron schedule for backups (e.g., `0 * * * *` for every hour at minute 0) 🗓️ [Cron schedule](https://en.wikipedia.org/wiki/Cron#Overview) |
| `BACKUP_RETENTION`| `10` (backups)         | Sets how many backup files are kept. |

### 👤 User PUID/PGID

These variables are used to set the user and group ID for the `foundry` user inside the container, which helps manage file permissions on mounted volumes.

| Variable | Default | Description                     |
|----------|---------|---------------------------------|
| `PUID`   | `1000`  | User ID for the foundry user.    |
| `PGID`   | `1000`  | Group ID for the foundry user.   |

To find your user's ID on Linux, you can use the command `id $(whoami)`.

## 🧪 Beta Branch

To use a beta branch of the game:

> [!WARNING]
> Do **not** use double ("") or single ('') quotes around the beta name or password.

 | Variable        | Default / Example | Description                                      |
|-----------------|-------------------|--------------------------------------------------|
| `BETANAME`     | `(none)`          | Name of the Steam beta branch to use.            |
| `BETAPASSWORD` | `(none)`          | Password for the beta branch, if required.       |

## 💖 Contributing

Feedback, bug reports, and pull requests are welcome! Please feel free to open an issue or submit a PR on the [GitHub repository](https://github.com/luxusburg/docker-foundry).
