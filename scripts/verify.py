#!/usr/bin/env python3
"""Headless acceptance for spooler-monitor-demo.

Runs Project/Sources/Methods/Demo_SelfTest.4dm under tool4d, then checks the
JSON report it writes. The read-only matrix is the default: nothing is paused,
resumed or printed. Pass --mutate <id> to include the explicit mutation pair
against a queue you own (scripts/demo_queue.py can stage a scratch one).

    python3 scripts/verify.py
    python3 scripts/verify.py --tool4d "/Applications/4D 21.2 LTS (100694)/tool4d.app/Contents/MacOS/tool4d"
    python3 scripts/verify.py --mutate spooler-demo

Exit status is 0 only when every executed check passed. Checks that this host
cannot execute are printed as not_run and never counted as success.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "Project" / "spooler-monitor-demo.4DProject"
COMPONENT = ROOT / "Components" / "spooler-monitor.4dbase"

EXPECTED_VERSION = "0.1.1"
EXPECTED_PROTOCOL = "1"
EXPECTED_OPERATIONS = "list,get,pause,resume"

READ_ONLY_CHECKS = (
    "version reads 0.1.1 with protocol 1",
    "capabilities name backend, operations, explicit-only policy",
    "list returns a queue collection",
    "unknown queue is unknown_queue, exit 3, not_submitted",
    "invalid id is rejected locally, before any process",
    "a foreign target is refused before launch",
)


def find_tool4d(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser()
    env = os.environ.get("TOOL4D")
    if env:
        return Path(env).expanduser()
    candidates = sorted(Path("/Applications").glob("4D*/tool4d.app/Contents/MacOS/tool4d"), reverse=True)
    if candidates:
        return candidates[0]
    raise SystemExit("tool4d not found: pass --tool4d or set TOOL4D")


def run_self_test(tool: Path, report: Path, mutate: str) -> tuple[int, str]:
    parameters: dict[str, str] = {"report": str(report)}
    if mutate:
        parameters["queue"] = mutate
    command = [
        str(tool),
        f"--project={PROJECT}",
        "--dataless",
        "--skip-onstartup",
        "--startup-method=Demo_SelfTest",
        f"--user-param={json.dumps(parameters)}",
    ]
    print("$", " ".join(command))
    completed = subprocess.run(command, text=True, capture_output=True, timeout=180)
    output = (completed.stdout or "") + (completed.stderr or "")
    return completed.returncode, output


def check_report(report: dict, mutate: str) -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    checks = {entry["name"]: entry for entry in report.get("checks", [])}

    if report.get("component") != "spooler-monitor":
        rows.append(("report identifies the component", "failed", str(report.get("component"))))
    if report.get("demo") != "spooler-monitor-demo":
        rows.append(("report identifies the demo", "failed", str(report.get("demo"))))
    if not report.get("finished"):
        rows.append(("report finished flag", "failed", "finished is not true"))

    for name in READ_ONLY_CHECKS:
        entry = checks.get(name)
        if entry is None:
            rows.append((name, "failed", "missing from the report"))
        elif entry.get("status") == "passed":
            rows.append((name, "passed", str(entry.get("detail", ""))))
        else:
            rows.append((name, "failed", str(entry.get("detail", ""))))

    get_name = "get returns the same id with an observation time"
    entry = checks.get(get_name)
    if entry is None:
        rows.append((get_name, "failed", "missing from the report"))
    elif entry.get("status") == "skipped":
        rows.append((get_name, "not_run", "no local queue to read (empty CUPS state)"))
    elif entry.get("status") == "passed":
        rows.append((get_name, "passed", str(entry.get("detail", ""))))
    else:
        rows.append((get_name, "failed", str(entry.get("detail", ""))))

    if mutate:
        for name in ("pause is accepted and observed as stopped",
                     "resume is accepted and observed as idle"):
            entry = checks.get(name)
            if entry is None:
                rows.append((name, "failed", "missing from the report"))
            elif entry.get("status") == "passed":
                rows.append((name, "passed", str(entry.get("detail", ""))))
            else:
                rows.append((name, "failed", str(entry.get("detail", ""))))
    else:
        rows.append(("pause/resume stay unexercised (explicit only)", "not_run",
                     "pass --mutate <queue> against a queue you own"))

    rows.append(("Windows-x64 CLI + winspool backend", "not_run", "macOS host"))
    rows.append(("Intel 4D host", "not_run", "Apple Silicon host"))
    rows.append(("dependency-manager installation", "not_run",
                 "the release is staged locally by scripts/fetch_dependency.py"))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool4d", default=None)
    parser.add_argument("--mutate", default="", metavar="QUEUE")
    parser.add_argument("--report", default="", help="keep the JSON report at this path")
    parser.add_argument("--show-output", action="store_true")
    args = parser.parse_args()

    tool = find_tool4d(args.tool4d)
    if not PROJECT.is_file():
        raise SystemExit(f"project not found: {PROJECT}")
    if not (COMPONENT / "Resources" / "bin" / "macOS" / "spooler-monitor").is_file():
        raise SystemExit("component not staged: run python3 scripts/fetch_dependency.py")

    temporary = ""
    if args.report:
        report_path = Path(args.report).expanduser()
    else:
        handle, temporary = tempfile.mkstemp(prefix="spooler-console-report", suffix=".json")
        os.close(handle)
        report_path = Path(temporary)

    try:
        code, output = run_self_test(tool, report_path, args.mutate)
        if args.show_output or code != 0:
            print(output.rstrip())
        if not report_path.is_file():
            print(output.rstrip())
            print(f"no report written at {report_path}", file=sys.stderr)
            return 1
        report = json.loads(report_path.read_text())
        rows = check_report(report, args.mutate)
    finally:
        if temporary:
            Path(temporary).unlink(missing_ok=True)

    width = max(len(name) for name, _, _ in rows)
    failed = 0
    for name, status, detail in rows:
        if status == "failed":
            failed += 1
        print(f"{status:7s} {name.ljust(width)}  {detail}")

    summary = report.get("summary", {})
    print()
    print(f"host: {platform.platform()}")
    print(f"tool4d: {tool}")
    print(f"component: {COMPONENT.name} · target {report.get('target')}")
    print(f"queues: {report.get('queueCount')} {report.get('queueIDs')}")
    print(f"self-test: passed={summary.get('passed')} failed={summary.get('failed')} "
          f"skipped={summary.get('skipped')}")
    print(f"result: {'passed' if failed == 0 else 'failed'}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
