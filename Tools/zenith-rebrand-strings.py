#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Satu Visual
"""Rename the brand inside Swift string literals: "Vorssaint" -> "Zenith".

Only text inside string literals changes. Comments, copyright headers, identifiers
(e.g. `keepAwakeActiveIconVorssaint`), interpolated code and lowercase IDs
(`com.vorssaint.*`) are left alone, which keeps the diff against upstream small.

    python3 Tools/zenith-rebrand-strings.py --check   # list leftovers, exit 1 if any
    python3 Tools/zenith-rebrand-strings.py --apply   # rewrite them

Run --check after every upstream sync (docs/FORK.md).
"""
import argparse
import glob
import re
import sys

OLD, NEW = "Vorssaint", "Zenith"
WORD = re.compile(r"(?<![A-Za-z0-9_])" + OLD + r"(?![A-Za-z0-9_])")

# Files whose literals must keep the upstream name, and why.
EXCLUDE = {
    # Only acts on a bundle with Zenith's own ID named "Vorssaint Utils.app": never runs.
    "Sources/Vorssaint/Core/BundleMigration.swift",
    # Verifies Vorssaint's Developer ID; updates are off in Zenith.
    "Sources/Vorssaint/Services/Update/UpdateInstallerSupport.swift",
}


def literal_spans(src):
    """Spans of literal text in Swift source, excluding comments and interpolations."""
    spans, stack = [], []
    mode = ("code", 0)
    i, n, seg_start = 0, len(src), 0
    while i < n:
        c = src[i]
        if mode[0] == "code":
            if src.startswith("//", i):
                j = src.find("\n", i)
                i = n if j < 0 else j
                continue
            if src.startswith("/*", i):
                depth, i = 1, i + 2
                while i < n and depth:
                    if src.startswith("/*", i):
                        depth, i = depth + 1, i + 2
                    elif src.startswith("*/", i):
                        depth, i = depth - 1, i + 2
                    else:
                        i += 1
                continue
            if c in '"#':
                m = re.match(r'(#*)("""|")', src[i:])
                if m:
                    stack.append(mode)
                    mode = ("str", m.group(2) == '"""', len(m.group(1)))
                    i += len(m.group(0))
                    seg_start = i
                    continue
            if c == "(":
                mode = ("code", mode[1] + 1)
            elif c == ")":
                if mode[1] == 0 and stack:
                    mode = stack.pop()
                    i += 1
                    seg_start = i
                    continue
                mode = ("code", mode[1] - 1)
            i += 1
            continue
        _, multi, hashes = mode
        close = ('"""' if multi else '"') + "#" * hashes
        esc = "\\" + "#" * hashes
        if src.startswith(esc + "(", i):
            spans.append((seg_start, i))
            stack.append(mode)
            mode = ("code", 0)
            i += len(esc) + 1
            continue
        if src.startswith(esc, i):
            i += len(esc) + 1
            continue
        if src.startswith(close, i):
            spans.append((seg_start, i))
            mode = stack.pop()
            i += len(close)
            continue
        i += 1
    return spans


def matches(src):
    spans = literal_spans(src)
    return [m for m in WORD.finditer(src) if any(a <= m.start() < b for a, b in spans)]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    total = 0
    for path in sorted(glob.glob("Sources/**/*.swift", recursive=True)):
        if path in EXCLUDE:
            continue
        src = open(path, encoding="utf-8").read()
        found = matches(src)
        if not found:
            continue
        total += len(found)
        if args.check:
            for m in found:
                line = src.count("\n", 0, m.start()) + 1
                text = src[src.rfind("\n", 0, m.start()) + 1:src.find("\n", m.start())].strip()
                print(f"{path}:{line}: {text[:120]}")
        else:
            out, last = [], 0
            for m in found:
                out += [src[last:m.start()], NEW]
                last = m.end()
            out.append(src[last:])
            open(path, "w", encoding="utf-8").write("".join(out))
            print(f"{path}: {len(found)}")
    verb = "found" if args.check else "replaced"
    print(f"{verb} {total} occurrence(s) of {OLD!r} in string literals")
    return 1 if args.check and total else 0


if __name__ == "__main__":
    sys.exit(main())
