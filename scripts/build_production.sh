#!/bin/bash

# Comprehensive Production APK Build Script for Durusuna Mobile
# Combines Firebase configuration, production backend, and APK building

set -e

echo "🚀 Building Durusuna Mobile Production APK"
echo "🔒 Includes Firebase configuration and production backend"
echo ""

# Load production environment variables
if [ -f .env.production ]; then
  export $(cat .env.production | xargs)
  echo "✅ Loaded production environment variables"
else
  echo "❌ Error: .env.production file not found"
  exit 1
fi

# Check if environment variables are set
check_env_var() {
    if [ -z "${!1}" ]; then
        echo "❌ Error: Environment variable $1 is not set"
        exit 1
    fi
}

# Check required environment variables
echo "🔍 Checking required environment variables..."

# Production backend
check_env_var "PRODUCTION_BACKEND_URL"

# Firebase configuration
echo "🔍 Checking Firebase environment variables..."
echo "   📱 Mobile app requires: FIREBASE_PROJECT_ID, API keys, app IDs, messaging sender ID"
echo "   🔧 Backend requires: FIREBASE_PROJECT_ID, service account key (NOT messaging sender ID)"
check_env_var "FIREBASE_PROJECT_ID"
check_env_var "FIREBASE_MESSAGING_SENDER_ID"
check_env_var "FIREBASE_ANDROID_API_KEY"
check_env_var "FIREBASE_ANDROID_APP_ID"

# iOS Firebase variables (optional for Android builds)
echo "🍎 Checking iOS Firebase variables (optional for Android builds)..."
FIREBASE_IOS_API_KEY=${FIREBASE_IOS_API_KEY:-""}
FIREBASE_IOS_APP_ID=${FIREBASE_IOS_APP_ID:-""}

# Optional: iOS Bundle ID (defaults to com.durusuna.mobile)
FIREBASE_IOS_BUNDLE_ID=${FIREBASE_IOS_BUNDLE_ID:-"com.durusuna.mobile"}

echo "✅ All environment variables are set"
echo "📡 Backend: $PRODUCTION_BACKEND_URL"
echo "🔥 Firebase Project: $FIREBASE_PROJECT_ID"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
cd android
./gradlew clean
cd ..

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build universal APK with all configurations
echo "🌐 Building production APK with Firebase and backend configuration..."
if flutter build apk --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=PRODUCTION_BACKEND_URL="$PRODUCTION_BACKEND_URL" \
  --dart-define=DEBUG_MODE=false \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_ANDROID_API_KEY="$FIREBASE_ANDROID_API_KEY" \
  --dart-define=FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID" \
  --dart-define=FIREBASE_IOS_API_KEY="$FIREBASE_IOS_API_KEY" \
  --dart-define=FIREBASE_IOS_APP_ID="$FIREBASE_IOS_APP_ID" \
  --dart-define=FIREBASE_IOS_BUNDLE_ID="$FIREBASE_IOS_BUNDLE_ID"; then
    echo "✅ Universal APK built successfully!"
    
    # Try building architecture-specific APKs for better compatibility
    echo "🏗️ Building architecture-specific APKs..."
    if flutter build apk --release --split-per-abi \
      --dart-define=ENVIRONMENT=production \
      --dart-define=PRODUCTION_BACKEND_URL="$PRODUCTION_BACKEND_URL" \
      --dart-define=DEBUG_MODE=false \
      --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
      --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
      --dart-define=FIREBASE_ANDROID_API_KEY="$FIREBASE_ANDROID_API_KEY" \
      --dart-define=FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID" \
      --dart-define=FIREBASE_IOS_API_KEY="$FIREBASE_IOS_API_KEY" \
      --dart-define=FIREBASE_IOS_APP_ID="$FIREBASE_IOS_APP_ID" \
      --dart-define=FIREBASE_IOS_BUNDLE_ID="$FIREBASE_IOS_BUNDLE_ID"; then
        echo "✅ Split APKs built successfully!"
    else
        echo "⚠️ Split APKs failed, but universal APK is ready"
    fi
else
    echo "❌ APK build failed"
    exit 1
fi

# Create distribution folder
DIST_DIR="production_apks"
rm -rf $DIST_DIR
mkdir -p $DIST_DIR

# Copy APKs to distribution folder
echo "📋 Organizing production APKs for distribution..."
cp build/app/outputs/apk/release/app-release.apk $DIST_DIR/durusuna-production-universal.apk

# Try to copy split APKs if they exist
if [ -f "build/app/outputs/apk/release/app-arm64-v8a-release.apk" ]; then
    cp build/app/outputs/apk/release/app-arm64-v8a-release.apk $DIST_DIR/durusuna-production-arm64-v8a.apk
    echo "✅ ARM64 APK copied"
else
    echo "⚠️ ARM64 APK not found"
fi

if [ -f "build/app/outputs/apk/release/app-armeabi-v7a-release.apk" ]; then
    cp build/app/outputs/apk/release/app-armeabi-v7a-release.apk $DIST_DIR/durusuna-production-armeabi-v7a.apk
    echo "✅ ARM APK copied"
else
    echo "⚠️ ARM APK not found"
fi

# Get APK info
APK_SIZE=$(du -h $DIST_DIR/durusuna-production-universal.apk | cut -f1)
APK_COUNT=$(ls -1 $DIST_DIR/*.apk | wc -l)

echo ""
echo "✅ Production build completed successfully!"
echo ""
echo "📱 Production APKs ready in: $DIST_DIR/"
echo "   📊 Total APKs: $APK_COUNT"
echo "   📏 Universal APK size: $APK_SIZE"
echo "   🔒 Firebase configuration: Injected"
echo "   📡 Backend: Production ($PRODUCTION_BACKEND_URL)"
echo ""
echo "🎯 RECOMMENDED FOR PRODUCTION:"
if [ -f "$DIST_DIR/durusuna-production-arm64-v8a.apk" ]; then
    echo "   1. Primary: durusuna-production-arm64-v8a.apk (modern devices)"
    echo "   2. Fallback: durusuna-production-universal.apk (universal compatibility)"
else
    echo "   📱 Use: durusuna-production-universal.apk (universal compatibility)"
fi
echo ""
echo "📱 DISTRIBUTION OPTIONS:"
echo "   • Internal testing: Share APK files directly"
echo "   • Cloud storage: Upload to secure cloud storage"
echo "   • USB transfer: Copy to device storage"
echo "   • ADB install: adb install $DIST_DIR/durusuna-production-universal.apk"
echo ""
echo "🔧 PRODUCTION INSTALLATION:"
echo "   1. Settings > Security > Install from Unknown Sources (Enable)"
echo "   2. Download APK to device"
echo "   3. Open with File Manager"
echo "   4. Tap Install and Allow permissions"
echo "   5. Verify production backend connection"
echo ""
echo "🔒 SECURITY NOTES:"
echo "   • Firebase secrets were injected at build time"
echo "   • Production backend URL is configured"
echo "   • Debug mode is disabled"
echo "   • Release build with optimizations enabled"
echo ""
echo "📋 REQUIRED ENVIRONMENT VARIABLES:"
echo "   • PRODUCTION_BACKEND_URL - Production backend endpoint"
echo "   • FIREBASE_PROJECT_ID - Firebase project ID (used by both mobile & backend)"
echo "   • FIREBASE_MESSAGING_SENDER_ID - Firebase messaging sender ID (mobile only, get from Firebase Console)"
echo "   • FIREBASE_ANDROID_API_KEY - Firebase Android API key"
echo "   • FIREBASE_ANDROID_APP_ID - Firebase Android app ID"
echo "   • FIREBASE_IOS_API_KEY - Firebase iOS API key (optional for Android builds)"
echo "   • FIREBASE_IOS_APP_ID - Firebase iOS app ID (optional for Android builds)"
echo "   • FIREBASE_IOS_BUNDLE_ID - Optional, defaults to com.durusuna.mobile" 