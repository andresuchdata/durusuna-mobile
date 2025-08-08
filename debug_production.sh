#!/bin/bash

# Parse command line arguments
DEVICE_NAME=""
if [ "$1" != "" ]; then
  DEVICE_NAME="$1"
fi

# Determine device ID based on device name
DEVICE_ID=""
if [ "$DEVICE_NAME" != "" ]; then
  case "$DEVICE_NAME" in
    "A16")
      DEVICE_ID="--device-id=RR8Y201QSAX"
      echo "🎯 Targeting device: A16 (RR8Y201QSAX)"
      ;;
    "iPhone")
      DEVICE_ID="--device-id=5F1AE46A-C2C6-4F14-B765-3D4A4907D284"
      echo "🎯 Targeting device: iPhone (5F1AE46A-C2C6-4F14-B765-3D4A4907D284)"
      ;;
    "android")
      DEVICE_ID="--device-id=emulator-5554"
      echo "🎯 Targeting device: android (emulator-5554)"
      ;;
    "mac")
      DEVICE_ID="--device-id=macos"
      echo "🎯 Targeting device: mac (macos)"
      ;;
    "chrome")
      DEVICE_ID="--device-id=chrome"
      echo "🎯 Targeting device: chrome (chrome)"
      ;;
    *)
      echo "❌ Error: Unknown device '$DEVICE_NAME'"
      echo "Available devices: A16, iPhone, mac, chrome"
      exit 1
      ;;
  esac
else
  echo "📱 No device specified, Flutter will prompt for device selection"
fi

# Load production environment variables
if [ -f .env.production ]; then
  export $(cat .env.production | xargs)
else
  echo "❌ Error: .env.production file not found"
  exit 1
fi

echo "🐛 Running Durusuna Mobile in Debug Mode with Production Backend"
echo "📡 Backend: $PRODUCTION_BACKEND_URL"
echo "🔍 Debug logging: ENABLED"
echo "🎯 High refresh rate optimizations: ENABLED"
echo "📊 Performance monitoring: ENABLED"
echo ""

# Debug build with production backend, logging, and high refresh rate optimizations
flutter run \
  $DEVICE_ID \
  --dart-define=ENVIRONMENT=production \
  --dart-define=PRODUCTION_BACKEND_URL=$PRODUCTION_BACKEND_URL \
  --dart-define=DEBUG_MODE=true \
  --dart-define=PERFORMANCE_MODE=high_refresh \
  --dart-define=ENABLE_PERFORMANCE_MONITORING=true \
  --dart-define=TARGET_REFRESH_RATE=120

echo "✅ Debug production build complete!"