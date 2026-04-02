#!/bin/bash
set -euo pipefail

BUILD_DIR=".build/release"
APP_DIR="KeepGoing.app/Contents"

swift build -c release

rm -rf KeepGoing.app
mkdir -p "$APP_DIR/MacOS"
cp "$BUILD_DIR/KeepGoing" "$APP_DIR/MacOS/KeepGoing"
cp Resources/Info.plist "$APP_DIR/Info.plist"

echo "Built KeepGoing.app"
