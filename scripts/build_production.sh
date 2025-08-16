#!/bin/bash

# Load production environment variables
if [ -f .env.production ]; then
  export $(cat .env.production | xargs)
else
  echo "❌ Error: .env.production file not found"
  exit 1
fi

echo "🚀 Building Durusuna Mobile for Production Testing"
echo "📡 Backend: $PRODUCTION_BACKEND_URL"
echo ""

# Production build with Railway backend
flutter run \
  --dart-define=ENVIRONMENT=production \
  --dart-define=PRODUCTION_BACKEND_URL=$PRODUCTION_BACKEND_URL \
  --dart-define=DEBUG_MODE=false \
  --release

echo "✅ Production build complete!" 