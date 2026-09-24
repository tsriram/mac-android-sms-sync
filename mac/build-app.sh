#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

swift build

APP="build/SMSync.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/debug/SMSync "$APP/Contents/MacOS/SMSync"
cp SMSync/Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - --entitlements SMSync/Resources/SMSync.entitlements "$APP"

echo "Built: $APP"