#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Satu Visual
"""Rebrand the upstream documentation that Zenith keeps.

These files stay close to upstream so they keep describing the code accurately.
After an upstream sync that touched one of them, take upstream's version and run
this again (docs/FORK.md, sync step 7):

    git checkout --theirs CONTRIBUTING.md && python3 Tools/zenith-rebrand-docs.py --apply

    python3 Tools/zenith-rebrand-docs.py --check   # list leftovers, exit 1 if any
    python3 Tools/zenith-rebrand-docs.py --apply   # rewrite in place (idempotent)
"""
import argparse
import re
import sys

FILES = [
    "CONTRIBUTING.md",
    "docs/PERMISSIONS.md",
    "docs/PRIVACY.md",
    "docs/TROUBLESHOOTING.md",
    "docs/SCROLL-ZOOM-TESTING.md",
    "docs/recorder-export-speed.md",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/config.yml",
    ".github/ISSUE_TEMPLATE/feature_request.yml",
]

# Order matters: specific forms first, the bare name last.
REPLACEMENTS = [
    ("github.com/vorssaint/vorssaint-utils/blob/main/", "github.com/satuvisual/zenith/blob/dev/"),
    ("github.com/vorssaint/vorssaint-utils", "github.com/satuvisual/zenith"),
    ("cd vorssaint-utils", "cd zenith"),
    ("com.vorssaint.utils.dev", "id.satuvisual.zenith.dev"),
    ("com.vorssaint.utils", "id.satuvisual.zenith"),
    (".config/vorssaint", ".config/zenith"),
    ("sudoers.d/vorssaint-clamshell", "sudoers.d/zenith-clamshell"),
    ("/var/run/vorssaint-", "/var/run/zenith-"),
    ("VorssaintDeveloper", "ZenithDeveloper"),
    ("VORSSAINT_RESOLVING_ENVIRONMENT", "ZENITH_RESOLVING_ENVIRONMENT"),
    ("`vorssaint-dev/`", "`zenith-dev/`"),
    ("`vorssaint/`", "`zenith/`"),
    ("vorssaint_version", "zenith_version"),
]
WORD = re.compile(r"(?<![A-Za-z0-9_])Vorssaint(?![A-Za-z0-9_])")

# Notes placed under the first heading, describing where Zenith differs.
NOTES = {
    "CONTRIBUTING.md": (
        "> **Zenith:** a personal project by Satu Visual. The branch model and upstream "
        "sync are in [docs/FORK.md](docs/FORK.md); the conventions below are the ones "
        "Zenith's code follows."
    ),
    "docs/PRIVACY.md": (
        "> **Zenith:** the update check, feedback, and temporary screenshot and recording "
        "links are turned off and never contact a server. The sections about them below "
        "describe code that Zenith keeps but does not use."
    ),
}
NOTE_MARK = "> **Zenith:**"


def rebrand(path, text):
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)
    text = WORD.sub("Zenith", text)
    note = NOTES.get(path)
    if note and NOTE_MARK not in text:
        lines = text.split("\n")
        heading = next((i for i, line in enumerate(lines) if line.startswith("# ")), None)
        if heading is not None:
            lines[heading + 1:heading + 1] = ["", note]
            text = "\n".join(lines)
    return text


def leftovers(text):
    return [(n, line.strip()) for n, line in enumerate(text.split("\n"), 1)
            if re.search("vorssaint", line, re.I)]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    remaining = 0
    for path in FILES:
        try:
            original = open(path, encoding="utf-8").read()
        except FileNotFoundError:
            continue
        updated = rebrand(path, original)
        if args.apply and updated != original:
            open(path, "w", encoding="utf-8").write(updated)
            print(f"rebranded {path}")
        current = updated if args.apply else original
        if args.check and updated != original:
            print(f"{path}: needs --apply")
            remaining += 1
        for n, line in leftovers(current):
            print(f"{path}:{n}: {line[:140]}")
            remaining += 1
    print(f"{remaining} item(s) to review")
    return 1 if args.check and remaining else 0


if __name__ == "__main__":
    sys.exit(main())
