#!/bin/bash
set -euo pipefail

APP_DIR="KeepGoing.app/Contents"

# Build universal binary
swift build -c release --arch arm64 --arch x86_64

rm -rf KeepGoing.app
mkdir -p "$APP_DIR/MacOS"

cp .build/apple/Products/Release/KeepGoing "$APP_DIR/MacOS/KeepGoing"
cp Resources/Info.plist "$APP_DIR/Info.plist"

# Also copy the CLI next to the .app for the installer
cp .build/apple/Products/Release/keepgoing-cli "$APP_DIR/MacOS/keepgoing-cli"

echo "Built KeepGoing.app (universal binary)"
