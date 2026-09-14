"""DSL for setting up Mixxx test profiles and managing Mixxx process lifecycle."""

import json
import os
import os
import shutil
import socket
import sqlite3
import subprocess
import glob
import sys
import tempfile
import threading
import random
import time
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET

TRACK_MANIFEST = os.path.join(os.path.dirname(__file__), "test_tracks.json")
SETTINGS_FILE = "mixxx.cfg"
DATABASE_FILE = "mixxxdb.sqlite"
SCHEMA_FILE = os.path.join(
    os.path.dirname(__file__),
    os.pardir,
    os.pardir,
    os.pardir,
    "res",
    "schema.xml",
)


def profile_dir():
    return os.path.join(os.path.expanduser("~"), ".mixxx-test-profile")


def database_path():
    return os.path.join(profile_dir(), DATABASE_FILE)


def mixxx_cfg_path():
    return os.path.join(profile_dir(), SETTINGS_FILE)


def load_track_manifest():
    with open(TRACK_MANIFEST) as f:
        return json.load(f)


def _parse_schema(schema_path):
    tree = ET.parse(schema_path)
    root = tree.getroot()
    statements = []
    for revision in root.findall("revision"):
        sql_el = revision.find("sql")
        if sql_el is None or not sql_el.text or not sql_el.text.strip():
            continue
        statements.append(sql_el.text.strip())
    return statements


def _read_schema_version(schema_path):
    """Return (latest_version, min_compatible_version) from the schema XML."""
    tree = ET.parse(schema_path)
    root = tree.getroot()
    latest_version = 0
    min_compatible = 0
    for revision in root.findall("revision"):
        ver = int(revision.get("version", "0"))
        if ver > latest_version:
            latest_version = ver
            min_compatible = int(revision.get("min_compatible", "0"))
    return latest_version, min_compatible


def _database_has_tables(db_path):
    try:
        cur = sqlite3.connect(db_path).cursor()
        cur.execute("SELECT count(*) FROM sqlite_master WHERE type='table'")
        count = cur.fetchone()[0]
        cur.connection.close()
        return count > 0
    except Exception:
        return False


def _download_file(entry, dest):
    url = entry["url"]
    req = urllib.request.Request(entry["url"], headers={"User-Agent": "MixxxTestProfile/1.0"})
    with tempfile.NamedTemporaryFile(delete_on_close=False) as f, tempfile.NamedTemporaryFile(delete_on_close=False) as c:
        with urllib.request.urlopen(req, timeout=30) as response:
            f.write(response.read())
            f.close()
        if "artwork" in entry and entry["artwork"]:
            req = urllib.request.Request(entry["artwork"], headers={"User-Agent": "MixxxTestProfile/1.0"})
            with urllib.request.urlopen(req, timeout=30) as response:
                c.write(response.read())
                c.close()
            p = subprocess.run([
                os.getenv("MIXXX_FFMPEG_BIN") or "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "info",
                "-i", f.name,
                "-i", c.name,
                "-map", "0:a", "-map", "1",
                "-c:a", "copy",
                "-c:v", "mjpeg",
                "-metadata", f"title={repr(entry['title'])}",
                "-metadata", f"artist={repr(entry['artist'])}",
                "-metadata:s:v", "title=\"Album cover\"",
                "-metadata:s:v", "comment=\"Cover (front)\"",
                dest
            ], text=True, capture_output=True)
            if p.returncode:
                print(p.returncode)
                print(p.stdout)
                print(p.stderr)
                sys.stdout.write(
                    f"  ffmpeg failed to mux artwork for {entry['url']}, "
                    f"falling back to raw MP3\n"
                )
                sys.stdout.flush()
                os.replace(f.name, dest)
        else:
            os.replace(f.name, dest)


def ensure_tracks_downloaded(target_dir=None, nb_tracks=20):
    """Download all tracks from the manifest into target_dir (or default tracks_dir)."""
    os.makedirs(target_dir, exist_ok=True)
    existing_track_count = len(glob.glob(f'{target_dir}/*.mp3'))
    if existing_track_count >= nb_tracks:
        return
    manifest = random.sample(load_track_manifest(), nb_tracks - existing_track_count)
    downloaded = []
    for entry in manifest:
        url = entry.get("url")
        if not url:
            continue
        a = urllib.parse.urlparse(url)
        filename = os.path.basename(a.path)
        dest = os.path.join(target_dir, filename)
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            downloaded.append(dest)
            continue
        sys.stdout.write(f"Downloading {filename}...\n")
        sys.stdout.flush()
        try:
            _download_file(entry, dest)
            if not os.path.exists(dest) or os.path.getsize(dest) == 0:
                raise RuntimeError(f"Download failed, no output at {dest}")
            downloaded.append(dest)
        except Exception as e:
            sys.stdout.write(f"  FAILED: {e}\n")
            sys.stdout.flush()
    return downloaded


def create_empty_profile(settings_dir=None):
    """Create a profile with schema-only database (no data rows)."""
    if settings_dir is None:
        settings_dir = profile_dir()
    os.makedirs(settings_dir, exist_ok=True)


def add_directory_to_db(track_dir, settings_dir=None):
    """Add a directory to the library's directory table."""
    if settings_dir is None:
        settings_dir = profile_dir()
    db_path = os.path.join(settings_dir, DATABASE_FILE)
    if not os.path.exists(db_path):
        return
    conn = sqlite3.connect(db_path)
    conn.execute(
        "INSERT OR IGNORE INTO directories (directory) VALUES (?)",
        (track_dir,),
    )
    conn.commit()
    conn.close()


_MIXXX_PROCESS = None


class MixxxProcess:
    """Manages a mixxx-test --serve subprocess for UI testing."""

    def __init__(self, binary, profile_dir, display=None):
        self.binary = binary
        self.profile_dir = profile_dir
        self.display = display
        self.process = None
        self.rpc = None

    def start(self, timeout=60):
        env = os.environ.copy()
        if self.display:
            env["DISPLAY"] = self.display

        args = [
            self.binary,
            "--serve",
            "--settings-path",
            self.profile_dir,
            "--developer",
            "--log-level",
            "debug",
        ]
        self.process = subprocess.Popen(
            args,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        output_lines = []

        def _pipe_logger():
            assert self.process is not None
            assert self.process.stdout is not None
            for line in self.process.stdout:
                # sys.stderr.write(line)
                output_lines.append(line)

        self._log_thread = threading.Thread(target=_pipe_logger, daemon=True)
        self._log_thread.start()

        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                s = socket.socket()
                s.settimeout(1)
                s.connect(("localhost", 9000))
                s.close()
                return
            except (OSError, ConnectionRefusedError):
                pass
            if self.process.poll() is not None:
                stderr_output = "".join(output_lines)
                if stderr_output:
                    print(stderr_output, file=sys.stderr)
                raise RuntimeError(
                    f"mixxx-test exited early with code {self.process.returncode}"
                )
            time.sleep(1)
        raise RuntimeError("Timed out waiting for Mixxx RPC on port 9000")

    def stop(self):
        if self.process is None:
            return
        self.process.terminate()
        try:
            self.process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        self.process = None

    def __enter__(self):
        self.start()
        global _MIXXX_PROCESS
        _MIXXX_PROCESS = self
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        global _MIXXX_PROCESS
        _MIXXX_PROCESS = None
        self.stop()


def current_mixxx():
    """Return the active MixxxProcess (set by context manager or start)."""
    return _MIXXX_PROCESS


def setup_profile(base_dir, profile_type):
    """Create a profile of the given type in base_dir.

    Types:
      'empty'   - Folder is ready
    """
    create_empty_profile(base_dir)
    return base_dir


def make_temp_profile(profile_type="empty"):
    """Create a temporary profile directory and return its path."""
    base = tempfile.mkdtemp(prefix="mixxx-test-profile-")
    return setup_profile(base, profile_type)


def cleanup_profile(profile_dir):
    """Remove a profile directory created by make_temp_profile."""
    if profile_dir and os.path.exists(profile_dir):
        shutil.rmtree(profile_dir, ignore_errors=True)
