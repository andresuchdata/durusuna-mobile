#!/bin/bash

# Secure build script for Durusuna Mobile with Firebase configuration
# This script injects Firebase configuration at build time from environment variables

set -e

echo "🔥 Building Durusuna Mobile with secure Firebase configuration..."

# Check if environment variables are set
check_env_var() {
    if [ -z "${!1}" ]; then
        echo "❌ Error: Environment variable $1 is not set"
        exit 1
    fi
}

# Check required environment variables for Firebase
echo "🔍 Checking Firebase environment variables..."
check_env_var "FIREBASE_PROJECT_ID"
check_env_var "FIREBASE_MESSAGING_SENDER_ID"
check_env_var "FIREBASE_ANDROID_API_KEY"
check_env_var "FIREBASE_ANDROID_APP_ID"
check_env_var "FIREBASE_IOS_API_KEY"
check_env_var "FIREBASE_IOS_APP_ID"

# Optional: iOS Bundle ID (defaults to com.durusuna.mobile)
FIREBASE_IOS_BUNDLE_ID=${FIREBASE_IOS_BUNDLE_ID:-"com.durusuna.mobile"}

echo "✅ All Firebase environment variables are set"

# Build for the specified target (default: apk)
BUILD_TARGET=${1:-"apk"}

echo "🚀 Building $BUILD_TARGET with secure configuration..."

# Build command with dart-define parameters
flutter build $BUILD_TARGET \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_ANDROID_API_KEY="$FIREBASE_ANDROID_API_KEY" \
  --dart-define=FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID" \
  --dart-define=FIREBASE_IOS_API_KEY="$FIREBASE_IOS_API_KEY" \
  --dart-define=FIREBASE_IOS_APP_ID="$FIREBASE_IOS_APP_ID" \
  --dart-define=FIREBASE_IOS_BUNDLE_ID="$FIREBASE_IOS_BUNDLE_ID" \
  --release

echo "✅ Build completed successfully!"
echo "🔒 Firebase secrets were injected at build time and are not stored in source code"
