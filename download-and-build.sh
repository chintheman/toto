#!/bin/bash
# Download iOS simulator and build TOTO app
# Run: nohup bash ~/projects/toto-ios-repo/download-and-build.sh > /tmp/toto-build.log 2>&1 &

set -e
REPO="$HOME/projects/toto-ios-repo"

echo "[$(date)] Starting iOS platform download..."
xcodebuild -downloadPlatform iOS 2>&1
echo "[$(date)] Platform installed. Creating simulator..."
xcrun simctl create "iPhone 16" "iPhone 16" "com.apple.CoreSimulator.SimRuntime.iOS-26-5" 2>&1 || true
echo "[$(date)] Building TotoApp..."
cd "$REPO/ios/TotoApp"
xcodebuild -project TotoApp.xcodeproj -scheme TotoApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1
echo "[$(date)] BUILD COMPLETE. Exit code: $?"
