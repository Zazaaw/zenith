#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
# Copyright (C) 2026 Satu Visual

set -euo pipefail
cd "$(dirname "$0")/.."
install_test_dir=$(mktemp -d)
trap 'command rm -rf "$install_test_dir"' EXIT

# Run the real installation block against disposable bundles. No process is
# stopped and no app under /Applications is read, removed or installed.
sed -n '/^if (( INSTALL )); then$/,$p' build.sh \
    | sed 's|/Applications|$install_test_dir/Applications|g' > "$install_test_dir/install.zsh"
[[ -s "$install_test_dir/install.zsh" ]]
mkdir -p "$install_test_dir/Applications" "$install_test_dir/stage"
print new > "$install_test_dir/stage/content"
INSTALL=1
STAGE="$install_test_dir/stage"
stopped=()
signed=()
stop_process() { stopped+=("$1"); }
sign_installed_bundle() { signed+=("$1"); }

# Zenith fork: both variants replace only their own bundle and stop only their
# own process. Vorssaint's apps (official or legacy) and the other Zenith
# variant are never stopped or removed.
others=(Vorss 'Vorssaint Utils' Vorssaint 'Vorssaint (Developer)' Zenith 'Zenith (Developer)')
for DEV in 1 0; do
    stopped=()
    signed=()
    for name in "${others[@]}"; do
        mkdir -p "$install_test_dir/Applications/$name.app"
        print original > "$install_test_dir/Applications/$name.app/content"
    done
    if (( DEV )); then
        APP_NAME='Zenith (Developer)'
        EXECUTABLE=ZenithDeveloper
    else
        APP_NAME=Zenith
        EXECUTABLE=Zenith
    fi
    source "$install_test_dir/install.zsh"
    [[ "$(cat "$install_test_dir/Applications/$APP_NAME.app/content")" == new ]]
    [[ "${signed[*]}" == "$install_test_dir/Applications/$APP_NAME.app" ]]
    [[ "${stopped[*]}" == "$EXECUTABLE" ]]
    for name in "${others[@]}"; do
        [[ "$name" == "$APP_NAME" ]] && continue
        [[ "$(cat "$install_test_dir/Applications/$name.app/content")" == original ]]
    done
done
print 'DEVELOPER INSTALL ISOLATION TESTS OK'
