#!/usr/bin/env python3
"""Stage the spooler-monitor component into Components/ for this demo.

The release asset is fetched from GitHub, its SHA256 is verified against a
pinned value, and the packed .4dbase is unpacked next to Project/. Run it once
before opening the project, or let 4D's Dependency Manager do the same job.

    python3 scripts/fetch_dependency.py            # fetch + verify + stage
    python3 scripts/fetch_dependency.py --check    # only report what is staged
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import stat
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

REPOSITORY = "miyako/spooler-monitor"
TAG = "0.1.1"
ASSET = "spooler-monitor.zip"
SHA256 = "4be30ab48f68501c3168865d401560321f3ca8b2a48b42f169a32ebac5977976"
URL = f"https://github.com/{REPOSITORY}/releases/download/{TAG}/{ASSET}"

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "Components" / "spooler-monitor.4dbase"


def check() -> int:
    if TARGET.is_dir():
        payload = TARGET / "Resources" / "bin" / "macOS" / "spooler-monitor"
        packed = TARGET / "spooler-monitor.4DZ"
        print(f"staged: {TARGET}")
        print(f"packed component: {'yes' if packed.is_file() else 'no'}")
        print(f"CLI executable: {'yes' if payload.is_file() else 'no'}")
        return 0
    print(f"not staged: {TARGET}")
    return 1


def download() -> bytes:
    print(f"fetching {URL}")
    with urllib.request.urlopen(URL, timeout=60) as response:
        return response.read()


def stage(archive: bytes) -> None:
    digest = hashlib.sha256(archive).hexdigest()
    print(f"sha256: {digest}")
    if digest != SHA256:
        raise SystemExit(f"checksum mismatch: expected {SHA256}")

    with tempfile.TemporaryDirectory() as scratch:
        path = Path(scratch) / ASSET
        path.write_bytes(archive)
        with zipfile.ZipFile(path) as zf:
            names = zf.namelist()
            if any(name.startswith("/") or ".." in Path(name).parts for name in names):
                raise SystemExit("refusing archive with unsafe member paths")
            zf.extractall(scratch)
        unpacked = [entry for entry in Path(scratch).iterdir() if entry.suffix == ".4dbase"]
        if len(unpacked) != 1:
            raise SystemExit(f"expected one .4dbase, found {[p.name for p in unpacked]}")
        if TARGET.exists():
            shutil.rmtree(TARGET)
        TARGET.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(unpacked[0], TARGET, symlinks=False)

    # The packed component keeps its CLI executable inside the archive; keep the
    # bit that makes it runnable after unpacking.
    payload = TARGET / "Resources" / "bin" / "macOS" / "spooler-monitor"
    if payload.is_file():
        payload.chmod(payload.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    print(f"staged: {TARGET}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report staging state only")
    args = parser.parse_args()
    if args.check:
        return check()
    print(f"{REPOSITORY} {TAG}")
    stage(download())
    return 0


if __name__ == "__main__":
    sys.exit(main())
