#!/bin/sh
# Builds Lecture Notes.app. Usage: ./build.sh [--run]
set -e
cd "$(dirname "$0")"
swift build -c release
APP="$PWD/Lecture Notes.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/NoteTaker "$APP/Contents/MacOS/NoteTaker"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "built: $APP"
[ "$1" = "--run" ] && open "$APP"
