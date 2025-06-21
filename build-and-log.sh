#!/bin/bash

# Usage: ./build_and_log.sh [device_id]

# Fail fast on any error
set -e

# Set your scheme and optional destination (edit as needed)
SCHEME="room-plan"  # <-- Replace with your scheme name
DEFAULT_SIMULATOR="platform=iOS Simulator,name=iPhone 14"

DEVICE_ID=$1

if [ -n "$DEVICE_ID" ]; then
  DESTINATION="id=$DEVICE_ID"
else
  DESTINATION="$DEFAULT_SIMULATOR"
fi

echo "Using destination: $DESTINATION"

# Output file
LOGFILE="build.log"

echo "📥 Pulling latest changes..."
git pull

echo "🛠️  Building $SCHEME ..."
xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" clean build | tee "$LOGFILE"

echo "✅ Done. Log saved to $LOGFILE"
