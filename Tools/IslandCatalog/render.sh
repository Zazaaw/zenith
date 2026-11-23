#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Satu Visual
#
# Zenith fork: renders the island catalog and builds its PDF.
#
#   Tools/IslandCatalog/render.sh [output folder] [pdf path]
#
# Needs a Developer build (./build.sh --dev). The renders run offscreen in the
# built app's `--render-island-catalog` mode, inside render.sb: no network,
# Keychain, preferences daemon, notifications, camera, or writes outside the
# output folder. A running Zenith is left alone. `ONLY=<id prefix>` renders
# just those shots and skips the PDF. `ONLY=readme` draws the README's
# pictures (the island over a sample wallpaper, the menu bar panel, Settings
# pages in their window), and `ONLY=motion…` frame sequences, which
# `ZENITH_MOTION_BACKDROP=wallpaper` draws over that wallpaper.
set -euo pipefail
cd "$(dirname "$0")/../.."

OUTPUT="${1:-$PWD/build/island-catalog}"
PDF="${2:-$PWD/build/Zenith-Dynamic-Island.pdf}"
APP="build/stage.noindex/Zenith (Developer).app"
BINARY="$APP/Contents/MacOS/ZenithDeveloper"
BUNDLE_ID="id.satuvisual.zenith.dev"

if [[ ! -x "$BINARY" ]]; then
    echo "✗ No Developer build at $APP — run ./build.sh --dev first" >&2
    exit 1
fi

mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd -P)"
ONLY_ARGS=()
[[ -n "${ONLY:-}" ]] && ONLY_ARGS=(--only "$ONLY")

echo "▸ Rendering the island offscreen into $OUTPUT…"
ZENITH_ISLAND_CATALOG_SANDBOX=1 nice -n 15 sandbox-exec -f Tools/IslandCatalog/render.sb \
    -D OUTPUT="$OUTPUT" \
    -D APP_SUPPORT="$HOME/Library/Application Support/$BUNDLE_ID" \
    -D KEYCHAINS="$HOME/Library/Keychains" \
    -D PREFERENCES="^$HOME/Library/Preferences/(ByHost/)?$BUNDLE_ID\\..*plist$" \
    "$BINARY" --render-island-catalog "$OUTPUT" "${ONLY_ARGS[@]}"

[[ -n "${ONLY:-}" ]] && exit 0

COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
[[ -n "$(git status --porcelain 2>/dev/null)" ]] && COMMIT="$COMMIT-dirty"
echo "▸ Building the PDF…"
nice -n 15 swift Tools/IslandCatalog/MakeCatalogPDF.swift "$OUTPUT" "$PDF" "$COMMIT"
echo "✓ $PDF"
