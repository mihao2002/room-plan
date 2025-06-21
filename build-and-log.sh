#!/bin/bash

# Fail fast on any error
set -e

# Set your scheme and optional destination (edit as needed)
SCHEME="MyApp"  # <-- Replace with your scheme name
DESTINATION="platform=iOS Simulator,name=iPhone 14"  # Optional for specific simulator

# Output file
LOGFILE="build.log"

echo "📥 Pulling latest changes..."
git pull

echo "🛠️  Building $SCHEME ..."
xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" clean build | tee "$LOGFILE"

echo "✅ Done. Log saved to $LOGFILE"
