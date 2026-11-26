#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Satu Visual
#
# Builds Zenith Pocket and installs it on the connected iPhone, and the
# Watch app on its Apple Watch when the Watch shows up as connected (with
# Developer Mode on); otherwise the iPhone installs the Watch app itself
# (Watch app on the iPhone → Pocket → Install).
#
#   ./install.sh                  first connected iPhone, team from the Apple Development certificate
#   POCKET_TEAM=ABCDE12345 ./install.sh
#   POCKET_DEVICE=paiz ./install.sh    (a device name or UDID)
#   POCKET_WATCH=<udid> ./install.sh   (the Watch, when more than one shows up)
#   ./install.sh --build-only     sign and build, don't install
#
# Uses Xcode at /Applications/Xcode.app without switching the system's
# developer directory (no xcode-select -s).

set -euo pipefail
cd "${0:A:h}"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD_ONLY=0
[[ "${1:-}" == "--build-only" ]] && BUILD_ONLY=1
DERIVED="build/DerivedData"
BUNDLE_ID="id.satuvisual.zenith.pocket"

fail() {
    print -u2 "\n✗ $1"
    shift
    for line in "$@"; do print -u2 "  $line"; done
    exit 1
}

[[ -d "$DEVELOPER_DIR" ]] || fail "Xcode isn't at $DEVELOPER_DIR." "Install Xcode, or set DEVELOPER_DIR to its Contents/Developer folder."
command -v xcodegen >/dev/null || fail "XcodeGen isn't installed." "brew install xcodegen"

# MARK: Team

team="${POCKET_TEAM:-}"
if [[ -z "$team" ]]; then
    # The team is the OU of an Apple Development certificate Xcode made.
    team=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null \
        | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)
fi
if [[ -z "$team" ]]; then
    fail "No signing team found." \
        "1. Open Xcode → Settings → Accounts, add your Apple ID (a free Personal Team works)." \
        "2. Select the team and click Manage Certificates → + → Apple Development." \
        "3. Run ./install.sh again, or set POCKET_TEAM to your 10-character Team ID."
fi
print "▸ Team $team"
export POCKET_TEAM="$team"

# MARK: Device

devices_json=$(mktemp -t pocket-devices)
trap 'rm -f "$devices_json"' EXIT
xcrun devicectl list devices --json-output "$devices_json" >/dev/null 2>&1 || true
# Prints the first physical device of a platform (iOS or watchOS), or the
# one named: udid, name, connected or away, dev or nodev.
find_device() {
    /usr/bin/python3 -I - "$devices_json" "$1" "${2:-}" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
platform, wanted = sys.argv[2], sys.argv[3]
for d in devices:
    p = d.get("properties", {})
    hw = p.get("hardware") or d.get("hardwareProperties", {})
    conn = p.get("connection") or d.get("connectionProperties", {})
    st = p.get("state") or d.get("deviceProperties", {})
    udid, name = hw.get("udid", ""), st.get("name", "")
    if hw.get("platform") != platform or hw.get("reality") != "physical":
        continue
    if wanted and wanted not in (udid, name):
        continue
    connected = (conn.get("state") or conn.get("tunnelState")) == "connected"
    mode = st.get("developerModeStatus")
    developer = mode == "enabled" or (isinstance(mode, dict) and "enabled" in mode)
    print(udid, name, "connected" if connected else "away", "dev" if developer else "nodev", sep="\t")
    break
PY
}
device=$(find_device iOS "${POCKET_DEVICE:-}")
watch=$(find_device watchOS "${POCKET_WATCH:-}")
udid=""
if [[ -n "$device" ]]; then
    IFS=$'\t' read -r udid name connection developer <<< "$device"
    [[ "$connection" == "connected" ]] || fail "$name isn't connected." "Plug the iPhone in (or put it on the same Wi-Fi) and unlock it."
    [[ "$developer" == "dev" ]] || fail "Developer Mode is off on $name." \
        "On the iPhone: Settings → Privacy & Security → Developer Mode → On, then restart it."
    print "▸ iPhone $name ($udid)"
elif (( ! BUILD_ONLY )); then
    fail "No iPhone found${POCKET_DEVICE:+ named $POCKET_DEVICE}." \
        "Connect it with a cable, unlock it, and tap Trust on the iPhone." \
        "Then check it shows up in: xcrun devicectl list devices"
fi
watch_udid=""
if [[ -n "$watch" ]]; then
    IFS=$'\t' read -r w_udid watch_name w_connection w_developer <<< "$watch"
    if [[ "$w_connection" == "connected" && "$w_developer" == "dev" ]]; then
        watch_udid="$w_udid"
        print "▸ Watch $watch_name ($watch_udid)"
    elif [[ "$w_developer" != "dev" ]]; then
        print "▸ $watch_name has Developer Mode off: the iPhone installs the Watch app instead."
    else
        print "▸ $watch_name isn't connected: the iPhone installs the Watch app instead."
    fi
fi

# MARK: Build

print "▸ Generating Pocket.xcodeproj"
xcodegen generate --quiet

destination="generic/platform=iOS"
[[ -n "$udid" ]] && destination="id=$udid"
print "▸ Building (signed for $team)"
log="build/xcodebuild.log"
mkdir -p build
if ! xcodebuild -project Pocket.xcodeproj -scheme Pocket -configuration Release \
        -destination "$destination" -derivedDataPath "$DERIVED" \
        -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
        DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic build > "$log" 2>&1; then
    grep -E "error:" "$log" | sort -u | head -10 >&2 || true
    fail "The build failed (full log: Pocket/$log)." \
        "No account or certificate: Xcode → Settings → Accounts, add your Apple ID, then try again." \
        "Device not registered or no profile: open Pocket.xcodeproj in Xcode once, pick your team under" \
        "Signing & Capabilities, choose the iPhone as destination and build (⌘B), then run this again." \
        "A free Personal Team allows 3 apps per device and its profiles last 7 days: reinstall weekly."
fi
app="$DERIVED/Build/Products/Release-iphoneos/Pocket.app"
watch_app="$DERIVED/Build/Products/Release-watchos/PocketWatch.app"
[[ -d "$app" ]] || fail "The build finished but $app is missing."
[[ -d "$app/Watch/PocketWatch.app" ]] || fail "The build finished but the Watch app isn't inside $app."
print "✓ Built $app (with the Watch app)"
(( BUILD_ONLY )) && exit 0

# MARK: Install

first_install=1
if xcrun devicectl device info apps --device "$udid" --bundle-id "$BUNDLE_ID" 2>/dev/null | grep -q "$BUNDLE_ID"; then
    first_install=0
fi
print "▸ Installing on $name"
xcrun devicectl device install app --device "$udid" "$app" \
    || fail "Installing failed." "Unlock the iPhone and keep it connected, then run ./install.sh again."
print "✓ Pocket is on $name."

if [[ -n "$watch_udid" ]]; then
    print "▸ Installing on $watch_name"
    if xcrun devicectl device install app --device "$watch_udid" "$watch_app"; then
        print "✓ Pocket is on $watch_name."
    else
        print "\n! Installing on the Watch failed. Keep it on its charger, unlocked and near the iPhone, then run" \
            "./install.sh again, or install it from the Watch app on the iPhone (My Watch → Pocket → Install)."
    fi
else
    print "\nThe Watch app rides inside Pocket: on the iPhone, open the Watch app → My Watch → Pocket → Install."
fi

if (( first_install )); then
    print "\nFirst install: before Pocket opens, trust the developer on the iPhone:"
    print "  Settings → General → VPN & Device Management → Apple Development: … → Trust."
fi
if ! xcrun devicectl device process launch --device "$udid" "$BUNDLE_ID" >/dev/null 2>&1; then
    print "\nOpen Pocket from the Home Screen (it couldn't be launched from here; trust the developer first if asked)."
fi
