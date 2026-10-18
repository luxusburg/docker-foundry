# Foundry Dedicated Server Docker Container 🏭

[![Docker Hub](https://img.shields.io/badge/Docker_Hub-foundry-blue?logo=docker)](https://hub.docker.com/r/luxusburg/docker-foundry)
[![Docker Pulls](https://img.shields.io/docker/pulls/luxusburg/docker-foundry)](https://hub.docker.com/r/luxusburg/docker-foundry)
[![Image Size](https://img.shields.io/docker/image-size/luxusburg/docker-foundry/latest)](https://hub.docker.com/r/luxusburg/docker-foundry/tags)
[![Github](https://img.shields.io/badge/Github-foundry-blue?logo=github)](https://github.com/luxusburg/docker-foundry)
![GitHub last commit](https://img.shields.io/github/last-commit/luxusburg/docker-foundry)

This Docker image simplifies hosting your own [Foundry](https://www.paradoxinteractive.com/games/foundry/about) dedicated server. 🚀

Tested and confirmed to work on Linux (Ubuntu/Debian). 🐧
Source code, issues and contributions: **[github.com/luxusburg/docker-foundry](https://github.com/luxusburg/docker-foundry)**

## ✨ Features

* 💨 Easy setup — a few environment variables and you are running.
* 🔄 Game server updated automatically on every container start (SteamCMD).
* 💾 Working, integrity-checked hourly backups with retention and a disk-space guard — plus a `backup.sh` tool to list/create/restore from the CLI or the web UI.
* 🖥️ Optional token-protected **web admin UI** (status, backups, config editor, log tail, restart) — no extra container.
* 🧩 Mod support and 🧪 Steam beta branch support.
* 🔍 Clean timestamped logging with a startup config banner and `LOG_LEVEL` control.
* 🛡️ Weekly automatic image rebuilds keep base-image security patches flowing.

## 🏷️ Image Tags

| Tag | Meaning |
|-----|---------|
| `latest` | Current release, automatic backups on by default |
| `non_cron` | Same image, automatic backups **off** by default (set `BACKUPS=true` to enable) |
| `1.7`, `1.7-non_cron` | Release 1.7 build (pinned version of the above) |

## 🚀 Quick Start

Create a directory for the server data first, e.g. `mkdir ~/foundry-server && cd ~/foundry-server`, then:

```bash
docker run -d \
    --name foundry-server \
    -p 3724:3724/udp \
    -p 27015:27015/udp \
    -v ./server:/home/foundry/server_files \
    -v ./data:/home/foundry/persistent_data \
    -e TZ="Europe/Paris" \
    -e SERVER_NAME="Foundry Docker by Luxusburg" \
    -e SERVER_PWD=change_me \
    luxusburg/docker-foundry:latest
```

Or with `docker-compose.yml`:

```yaml
services:
  foundry:
    container_name: foundry-server
    image: luxusburg/docker-foundry:latest
    network_mode: bridge
    environment:
      - TZ=Europe/Paris
      - WORLD_NAME=myworld
      - SERVER_PWD=change_me_strong_password
      - SERVER_NAME=Foundry Docker - by Luxusburg
      - SERVER_MAX_PLAYERS=10
      - SERVER_IS_PUBLIC=true
      - PAUSE_SERVER_WHEN_EMPTY=false
      - AUTOSAVE_INTERVAL=300
      - MAX_TRANSFER_RATE=8192
      # Backups (already on by default)
      - BACKUPS=true
      - BACKUP_INTERVAL=0 * * * *   # every hour; do NOT quote this value
      - BACKUP_RETENTION=10         # keep the last 10 backup files
      # - ENABLE_MODS=true
      # - PUID=1000
      # - PGID=1000
    volumes:
      - ./server:/home/foundry/server_files:rw
      - ./data:/home/foundry/persistent_data:rw
    ports:
      - "3724:3724/udp"
      - "27015:27015/udp"   # only needed if SERVER_IS_PUBLIC=true
    restart: unless-stopped
```

Then `docker compose up -d` and check `docker logs -f foundry-server` — a startup banner shows the effective configuration.

## 🗂️ Volumes

* `/home/foundry/server_files` (e.g. `./server`): game server files, `app.cfg`, mods.
* `/home/foundry/persistent_data` (e.g. `./data`): world saves (`save/<WORLD_NAME>/`), backups (`backup/`), logs.

💡 **Tip:** fine-tune via `./server/app.cfg` after the first run, or fully manage it yourself with `CUSTOM_CONFIG=true`. All official `app.cfg` options: [Foundry Dedicated Server Docs](https://dedicated.foundry-game.com/)

## 💾 Backups & Restore

Backups are on by default: an in-container scheduler (no cron daemon) runs them on your `BACKUP_INTERVAL`, honoring `TZ`, as the `foundry` user, visible in `docker logs`. Archives go to `./data/backup/foundry_backup-*.tar.gz`, each integrity-checked before keeping; a disk-space guard (`MIN_FREE_MB`) skips instead of filling your volume.

```bash
docker exec foundry-server /home/foundry/scripts/backup.sh --list
docker exec foundry-server /home/foundry/scripts/backup.sh --create
docker exec foundry-server /home/foundry/scripts/backup.sh --restore latest
docker restart foundry-server        # restore is applied safely on next start
```

♻️ Restore is **deferred by default**: it is applied on the next container start, before the server boots, and the save that was active is always kept in a `pre_restore_*` safety folder. Manual `tar -xzvf ./data/backup/foundry_backup-<name>.tar.gz -C ./data/` works too (overwrites current saves!).

## 🖥️ Web Admin UI (optional, off by default)

```yaml
    environment:
      - WEBUI=true
      - WEBUI_TOKEN=<long-r…oken>   # REQUIRED - UI refuses to start without it
    ports:
      - "8080:8080"                 # only map if you want it reachable
```

Open `http://<host>:8080/`, enter the token: live server status, create/list/**restore** backups, edit `app.cfg`, tail logs, restart the container — all in the browser. ⚠️ The token is the only gate: keep the port private or firewalled, use a long random token. (The game server has no RCON, so no in-game commands — by design.)

## 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Europe/Paris` | Container timezone 🌍 |
| `WORLD_NAME` | `FoundryDockerWorld` | World / save folder name 🗺️ (case-sensitive; the container warns before it would split an existing save by case) |
| `SERVER_PWD` | (none) | Server password 🔑 — **highly recommended** |
| `SERVER_NAME` | `Foundry Docker Server` | Server browser name 📢 |
| `MAP_SEED` | (game default) | Map seed 🌱 (written as the official `mapseed` option; legacy `map_seed=` lines migrate automatically) |
| `SERVER_MAX_PLAYERS` | `10` | Max players 🧑‍🤝‍🧑 |
| `PAUSE_SERVER_WHEN_EMPTY` | `false` | Pause when nobody is connected ⏸️ |
| `AUTOSAVE_INTERVAL` | `300` | Autosave every N seconds ⏱️ |
| `SERVER_IS_PUBLIC` | `false` | List on the Steam server browser 🌐 |
| `SERVER_PORT` | `3724` | Game port 🔌 |
| `SERVER_QUERY_PORT` | `27015` | Steam query port 📡 (public servers) |
| `MAX_TRANSFER_RATE` | `1024` | Client transfer rate, KiB/s, max `8192` 📶 |
| `CUSTOM_CONFIG` | `false` | `true` = never touch your own `app.cfg` 📝 |
| `LOG_LEVEL` | `info` | `error` / `warn` / `info` / `trace` 🔍 |
| `BACKUPS` | `true` | Enable automatic backups |
| `BACKUP_INTERVAL` | `0 * * * *` | Cron schedule — do NOT quote the value 🗓️ |
| `BACKUP_RETENTION` | `10` | Number of backup files kept |
| `MIN_FREE_MB` | `500` | Free-space guard before a backup runs 🛡️ |
| `NO_CRON` | (unset) | Legacy: any value disables backups entirely |
| `PUID` / `PGID` | `1000` | File ownership on your volumes (`id $(whoami)`) |
| `BETANAME` / `BETAPASSWORD` | (none) | Steam beta branch — no quotes around the values 🧪 |
| `ENABLE_MODS` | `false` | Download subscribed mods at startup 🧩 |
| `WEBUI` / `WEBUI_TOKEN` / `WEBUI_PORT` | `false` / — / `8080` | Optional admin UI 🖥️ |

## 🔄 Staying Up to Date

* The **game server** updates via SteamCMD on every container start.
* The **Debian base + packages** refresh via weekly automated image rebuilds (Mondays, UTC).
* To pick up a newer image: `docker compose pull && docker compose up -d`.

## 🧩 Mods

Set `ENABLE_MODS=true` and copy your client-generated `modList.json` into `./server/Mods/` (Windows client: `...\Steam\steamapps\common\FOUNDRY\Mods\modList.json`). Mods download/update at startup; per-mod settings live in `./data/mod_settings/`.

## 💖 Contributing

Feedback, bug reports and pull requests are welcome on [GitHub](https://github.com/luxusburg/docker-foundry) — open an issue or a PR!
