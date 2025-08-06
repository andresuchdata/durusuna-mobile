#!/bin/bash

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
  --dart-define=ENVIRONMENT=production \
  --dart-define=PRODUCTION_BACKEND_URL=$PRODUCTION_BACKEND_URL \
  --dart-define=DEBUG_MODE=true \
  --dart-define=PERFORMANCE_MODE=high_refresh \
  --dart-define=ENABLE_PERFORMANCE_MONITORING=true \
  --dart-define=TARGET_REFRESH_RATE=120

echo "✅ Debug production build complete!" 