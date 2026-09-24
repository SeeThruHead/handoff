#!/bin/bash
# Builds Handoff.app (tray app) with the handoff CLI inside its bundle.
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${1:-0.1.0}"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos12.0"
APP="build/Handoff.app"

mkdir -p build
echo "Building handoff CLI..."
swiftc -O -o build/handoff-cli CLI/main.swift Shared/*.swift -framework Cocoa -target "$TARGET"
echo "Building Handoff app..."
swiftc -O -o build/HandoffApp App/*.swift Shared/*.swift -framework Cocoa -framework SwiftUI -framework WebKit -target "$TARGET"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp build/HandoffApp "$APP/Contents/MacOS/Handoff"
cp build/handoff-cli "$APP/Contents/Helpers/handoff"
cp Resources/SKILL.md "$APP/Contents/Resources/SKILL.md"
sed "s/\$(MARKETING_VERSION)/$VERSION/" Resources/Info.plist > "$APP/Contents/Info.plist"
codesign -s - --force --deep "$APP"
echo "Built $APP (v$VERSION, $ARCH)"
