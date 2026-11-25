#!/usr/bin/env python3
"""Create or remove a harmless scratch CUPS queue for the demo.

A macOS host with no configured printers still returns a successful, empty
`list()`, which the console explains in its empty state. If you want rows to
click, this script registers a queue whose device discards everything.

    python3 scripts/demo_queue.py --create    # lpadmin -p spooler-demo ...
    python3 scripts/demo_queue.py --remove

The queue is a local file:///dev/null device: nothing is printed, nothing
leaves the machine, and `pause`/`resume` only change its CUPS state.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys

QUEUE = "spooler-demo"
PPD = "drv:///sample.drv/generic.ppd"
DEVICE = "file:///dev/null"


def run(args: list[str]) -> int:
    print("$", " ".join(args))
    completed = subprocess.run(args, text=True, capture_output=True)
    if completed.stdout.strip():
        print(completed.stdout.strip())
    if completed.stderr.strip():
        print(completed.stderr.strip())
    return completed.returncode


def create() -> int:
    if shutil.which("lpadmin") is None:
        print("lpadmin not found: this helper only works on a CUPS host (macOS/Linux)")
        return 2
    for args in (["lpadmin", "-p", QUEUE, "-E", "-v", DEVICE, "-m", PPD],
                 ["cupsaccept", QUEUE] if shutil.which("cupsaccept") else None):
        if args is None:
            continue
        code = run(args)
        if code != 0:
            return code
    print(f"created {QUEUE}; remove it again with --remove")
    return 0


def remove() -> int:
    if shutil.which("lpadmin") is None:
        print("lpadmin not found: nothing to remove here")
        return 2
    code = run(["lpadmin", "-x", QUEUE])
    if code == 0:
        print(f"removed {QUEUE}")
    return code


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--create", action="store_true")
    group.add_argument("--remove", action="store_true")
    args = parser.parse_args()
    return create() if args.create else remove()


if __name__ == "__main__":
    sys.exit(main())
