#!/usr/bin/env python3
"""Minimal web admin UI for the Foundry dedicated server container.

Standard library only - no pip packages, no extra runtime dependencies. The
container gets a small HTTP/JSON API (plus a static page served from
webui_index.html) that can report status, list/create/restore backups, edit
app.cfg, tail the container log and restart the container.

Environment:
  PERSISTENT_DATA  save/backup root            (default /home/foundry/persistent_data)
  SERVER_FILES     Foundry install directory    (default /home/foundry/server_files)
  WEBUI_TOKEN      bearer token, REQUIRED       (no default - refuses to start)
  WEBUI_PORT       listen port                  (default 8080)
  WEBUI_BIND       bind address                 (default 0.0.0.0)
  BACKUP_SH        path to backup.sh            (default <dir of this file>/backup.sh)
  CONTAINER_LOG    log file to tail             (default PERSISTENT_DATA/logs/container.log)

Every path below /api/ needs 'Authorization: Bearer <token>'. '/' and
'/index.html' are unauthenticated and serve the static page.
"""

import glob
import hmac
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))

PERSISTENT_DATA = os.environ.get("PERSISTENT_DATA") or "/home/foundry/persistent_data"
SERVER_FILES = os.environ.get("SERVER_FILES") or "/home/foundry/server_files"
WEBUI_TOKEN = os.environ.get("WEBUI_TOKEN") or ""
WEBUI_PORT = int(os.environ.get("WEBUI_PORT") or "8080")
WEBUI_BIND = os.environ.get("WEBUI_BIND") or "0.0.0.0"
BACKUP_SH = os.environ.get("BACKUP_SH") or os.path.join(HERE, "backup.sh")
CONTAINER_LOG = os.environ.get("CONTAINER_LOG") or os.path.join(
    PERSISTENT_DATA, "logs", "container.log"
)
INDEX_HTML = os.path.join(HERE, "webui_index.html")

BACKUP_DIR = os.path.join(PERSISTENT_DATA, "backup")
BACKUP_GLOB = os.path.join(BACKUP_DIR, "foundry_backup-*.tar.gz")
# A backup name is a plain archive name: prefix, timestamp-ish characters, and
# it must end in a digit before the suffix. No slashes, no '..', no '.' start.
BACKUP_NAME_RE = re.compile(r"foundry_backup-[0-9_.:-]+[0-9]\.tar\.gz\Z")
CONFIG_PATH = os.path.join(SERVER_FILES, "app.cfg")
PERSISTENT_DATA_OVERRIDE = "/home/foundry/persistent_data"
OVERRIDE_LINE_RE = re.compile(
    r"^\s*server_persistent_data_override_folder\s*=\s*(.*?)\s*$", re.IGNORECASE
)

BACKUP_TIMEOUT = 600
DEFAULT_LOG_LINES = 200
MAX_LOG_LINES = 2000
PROC_PATTERN = "FoundryDedicatedServer.exe"


# --- helpers ----------------------------------------------------------------


def env_flag(name, default=False):
    """Read a 'true'/'false' style environment flag."""
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def to_int(value, default):
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return default


def backup_files():
    """Existing archives as (path, name, bytes, mtime), oldest first."""
    entries = []
    for path in glob.glob(BACKUP_GLOB):
        try:
            st = os.stat(path)
        except OSError:
            continue
        if not os.path.isfile(path):
            continue
        # (mtime, bytes, path) sorted oldest first
        entries.append((st.st_mtime, st.st_size, path))
    entries.sort()
    return [
        (path, os.path.basename(path), size, mtime) for mtime, size, path in entries
    ]


def server_pid():
    """First pid whose command line contains the dedicated server binary."""
    try:
        out = subprocess.run(
            ["pgrep", "-f", PROC_PATTERN],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    for line in (out.stdout or "").splitlines():
        line = line.strip()
        if line.isdigit():
            pid = int(line)
            if pid != os.getpid():
                return pid
    return None


def uptime_seconds(pid):
    """Process age in seconds from 'ps -o etimes='."""
    try:
        out = subprocess.run(
            ["ps", "-o", "etimes=", "-p", str(pid)],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    text = (out.stdout or "").strip()
    if not text:
        return None
    return to_int(text.splitlines()[-1], None)


def read_text(path):
    try:
        with open(path, "r", errors="replace") as handle:
            return handle.read()
    except OSError:
        return ""


def tail_lines(path, count):
    """Last `count` lines of a file; [] when the file is missing/unreadable."""
    try:
        with open(path, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            pos = handle.tell()
            data = b""
            block = 64 * 1024
            while pos > 0 and data.count(b"\n") <= count:
                read = min(block, pos)
                pos -= read
                handle.seek(pos)
                data = handle.read(read) + data
    except OSError:
        return []
    lines = data.decode("utf-8", "replace").splitlines()
    if count and len(lines) > count:
        lines = lines[-count:]
    return lines


def run_backup(args, timeout=BACKUP_TIMEOUT):
    """Run backup.sh with the container's environment; returns (returncode, output)."""
    env = dict(os.environ)
    env["PERSISTENT_DATA"] = PERSISTENT_DATA
    proc = subprocess.run(
        ["bash", BACKUP_SH] + args,
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    output = (proc.stdout or "") + (proc.stderr or "")
    return proc.returncode, output


def bad_override(text):
    """True when `text` would move the persistent data folder somewhere else."""
    for line in (text or "").splitlines():
        match = OVERRIDE_LINE_RE.match(line)
        if not match:
            continue
        value = match.group(1).strip().strip("'\"")
        if value != PERSISTENT_DATA_OVERRIDE:
            return True
    return False


class Handler(BaseHTTPRequestHandler):
    server_version = "FoundryWebUI/1.0"
    protocol_version = "HTTP/1.1"

    # --- plumbing -----------------------------------------------------------

    def log_message(self, fmt, *args):  # silenced; we log our own request line
        pass

    def _request_path(self):
        try:
            return urlparse(self.path)
        except ValueError:
            return urlparse("/")

    def _respond(self, status, body, content_type="application/json"):
        if isinstance(body, str):
            body = body.encode("utf-8")
        try:
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)
        except OSError:
            pass
        self._log_request(status)

    def _log_request(self, status):
        print("%s %s %s" % (self.command, self._request_path().path, status), flush=True)

    def _json(self, status, payload):
        self._respond(status, json.dumps(payload).encode("utf-8"))

    def _error(self, status, message):
        self._json(status, {"error": message})

    def _unauthorized(self):
        self._error(401, "unauthorized")

    def _not_found(self):
        self._error(404, "not found")

    def _authorized(self):
        header = self.headers.get("Authorization") or ""
        if not header.startswith("Bearer "):
            return False
        token = header[len("Bearer "):].strip()
        # Compare as UTF-8 bytes: str-vs-str compare_digest raises TypeError
        # on non-ASCII characters, which would leak as an HTTP 500 instead of
        # a clean 401 (found during live testing with a token containing
        # non-ASCII characters). Any auth oddity must never be a 5xx.
        try:
            return hmac.compare_digest(token.encode("utf-8"), WEBUI_TOKEN.encode("utf-8"))
        except Exception:
            return False

    def _body_json(self):
        """Parsed JSON request body, or {} when absent/invalid."""
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = 0
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        if not raw:
            return {}
        try:
            data = json.loads(raw.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return None
        return data

    # --- dispatch -----------------------------------------------------------

    def _handle(self, method):
        try:
            parsed = self._request_path()
            path = parsed.path
            if method == "GET" and path in ("/", "/index.html"):
                return self._serve_index()
            if not path.startswith("/api/"):
                return self._not_found()
            if not self._authorized():
                return self._unauthorized()
            return self._api(method, path, parse_qs(parsed.query))
        except Exception as exc:  # never leak a traceback to the client
            traceback.print_exc()
            try:
                self._error(500, str(exc))
            except Exception:
                pass

    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def do_PUT(self):
        self._handle("PUT")

    def do_HEAD(self):
        self._handle("HEAD")

    # --- static -------------------------------------------------------------

    def _serve_index(self):
        try:
            with open(INDEX_HTML, "rb") as handle:
                body = handle.read()
        except OSError:
            return self._respond(200, "placeholder", content_type="text/plain; charset=utf-8")
        return self._respond(200, body, content_type="text/html; charset=utf-8")

    # --- API ----------------------------------------------------------------

    def _api(self, method, path, query):
        if method == "GET" and path == "/api/status":
            return self._api_status()
        if method == "GET" and path == "/api/backups":
            return self._api_backups_list()
        if method == "POST" and path == "/api/backups":
            return self._api_backups_create()
        if method == "POST" and path == "/api/backups/restore":
            return self._api_backup_restore()
        if method == "GET" and path == "/api/config":
            return self._api_config_get()
        if method == "PUT" and path == "/api/config":
            return self._api_config_put()
        if method == "GET" and path == "/api/logs":
            return self._api_logs(query)
        if method == "POST" and path == "/api/restart":
            return self._api_restart()
        return self._not_found()

    def _api_status(self):
        pid = server_pid()
        running = pid is not None
        uptime = uptime_seconds(pid) if running else None

        count, total_bytes = 0, 0
        for _path, _name, size, _mtime in backup_files():
            count += 1
            total_bytes += size

        try:
            usage = shutil.disk_usage(PERSISTENT_DATA)
            free_bytes, total_disk = usage.free, usage.total
        except OSError:
            free_bytes, total_disk = 0, 0

        self._json(
            200,
            {
                "running": running,
                "uptime_seconds": uptime if running else None,
                "world": os.environ.get("WORLD_NAME") or "FoundryDockerWorld",
                "server_name": os.environ.get("SERVER_NAME") or "Foundry Docker Server",
                "is_public": env_flag("SERVER_IS_PUBLIC", False),
                "port": to_int(os.environ.get("SERVER_PORT"), 3724),
                "query_port": to_int(os.environ.get("SERVER_QUERY_PORT"), 27015),
                "mods": env_flag("ENABLE_MODS", False),
                "backups": {"count": count, "total_bytes": total_bytes},
                "disk": {"free_bytes": free_bytes, "total_bytes": total_disk},
            },
        )

    def _api_backups_list(self):
        self._json(
            200,
            {
                "backups": [
                    {"name": name, "bytes": size, "mtime": int(mtime)}
                    for _path, name, size, mtime in backup_files()
                ]
            },
        )

    def _api_backups_create(self):
        try:
            code, output = run_backup(["--create"])
        except subprocess.TimeoutExpired:
            return self._error(500, "backup timed out after %ss" % BACKUP_TIMEOUT)
        lines = output.splitlines()[-40:]
        self._json(200, {"ok": code == 0, "output": "\n".join(lines)})

    def _api_backup_restore(self):
        body = self._body_json()
        if not isinstance(body, dict):
            return self._error(400, "invalid JSON body")
        name = body.get("name")
        if not isinstance(name, str) or not BACKUP_NAME_RE.match(name):
            return self._error(400, "invalid backup name")
        try:
            code, output = run_backup(["--restore", name])
        except subprocess.TimeoutExpired:
            return self._error(500, "restore timed out after %ss" % BACKUP_TIMEOUT)
        lines = output.splitlines()
        last_line = lines[-1] if lines else ""
        self._json(200, {"ok": code == 0, "output_last_line": last_line})

    def _api_config_get(self):
        self._json(200, {"text": read_text(CONFIG_PATH)})

    def _api_config_put(self):
        body = self._body_json()
        if not isinstance(body, dict) or not isinstance(body.get("text"), str):
            return self._error(400, "expected JSON body {text: ...}")
        text = body["text"]
        if bad_override(text):
            return self._error(
                400,
                "server_persistent_data_override_folder must stay %s"
                % PERSISTENT_DATA_OVERRIDE,
            )
        if os.path.isfile(CONFIG_PATH):
            try:
                shutil.copy2(CONFIG_PATH, CONFIG_PATH + ".bak")
            except OSError as exc:
                return self._error(500, "could not back up app.cfg: %s" % exc)
        try:
            with open(CONFIG_PATH, "w") as handle:
                handle.write(text)
        except OSError as exc:
            return self._error(500, "could not write app.cfg: %s" % exc)
        self._json(200, {"ok": True})

    def _api_logs(self, query):
        raw = (query.get("lines") or [str(DEFAULT_LOG_LINES)])[0]
        count = to_int(raw, DEFAULT_LOG_LINES)
        if count < 1:
            count = 1
        if count > MAX_LOG_LINES:
            count = MAX_LOG_LINES
        self._json(200, {"lines": tail_lines(CONTAINER_LOG, count)})

    def _api_restart(self):
        self._json(200, {"ok": True, "note": "container restarting"})

        def _signal_init():
            try:
                os.kill(1, 15)
            except OSError as exc:
                print("restart: could not signal PID 1: %s" % exc, file=sys.stderr, flush=True)

        timer = threading.Timer(0.5, _signal_init)
        timer.daemon = True
        timer.start()


def main():
    if not WEBUI_TOKEN:
        print(
            "WEBUI enabled but WEBUI_TOKEN is not set - refusing to start",
            file=sys.stderr,
        )
        raise SystemExit(1)
    server = ThreadingHTTPServer((WEBUI_BIND, WEBUI_PORT), Handler)
    server.daemon_threads = True
    print(
        "web UI listening on %s:%s (pid %s, %s)"
        % (WEBUI_BIND, WEBUI_PORT, os.getpid(), time.strftime("%Y-%m-%d %H:%M:%S")),
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
