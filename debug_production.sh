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
echo ""

# Debug build with production backend but with logging enabled
flutter run \
  --dart-define=ENVIRONMENT=production \
  --dart-define=PRODUCTION_BACKEND_URL=$PRODUCTION_BACKEND_URL \
  --dart-define=DEBUG_MODE=true

echo "✅ Debug production build complete!" 