#!/bin/bash

set -e

# === CONFIG ===
SCHEME="room-plan"
PROJECT_DIR="$(pwd)"
DERIVED_DATA_PATH="$PROJECT_DIR/build"
BUILD_CONFIG="Debug"

# Automatically get first connected iPhone's ID
DEVICE_ID=$(xcrun xctrace list devices | grep -v Simulator | grep -m 1 -oE '\([A-F0-9-]+\)' | tr -d '()')

if [ -z "$DEVICE_ID" ]; then
  echo "❌ No physical iPhone connected. Please connect a device via USB."
  exit 1
fi

echo "📱 Using device: $DEVICE_ID"

# === BUILD ===
echo "🚧 Building the app..."
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$BUILD_CONFIG" \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean build | tee "$PROJECT_DIR/build.log"

# === INSTALL ===
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$BUILD_CONFIG-iphoneos/$SCHEME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "❌ Build failed or .app not found at $APP_PATH"
  exit 1
fi

echo "📦 Installing app to device..."
ios-deploy --id "$DEVICE_ID" --bundle "$APP_PATH" --justlaunch

echo "✅ App installed and launched successfully on device: $DEVICE_ID"
