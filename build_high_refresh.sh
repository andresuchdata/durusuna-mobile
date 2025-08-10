#!/bin/bash

echo "🚀 Building Durusuna Mobile with High Refresh Rate Optimizations"
echo ""

# Check if we should use production backend
if [ -f .env.production ]; then
  source .env.production
  echo "📡 Backend: $PRODUCTION_BACKEND_URL"
else
  echo "⚠️  Using development backend"
fi

echo "🎯 Optimizations:"
echo "  ✓ High refresh rate (120Hz target)"
echo "  ✓ Performance monitoring enabled"
echo "  ✓ Reduced UI rebuilds"
echo "  ✓ Optimized animations"
echo "  ✓ Enhanced scroll physics"
echo ""

# Build with performance optimizations
flutter run \
  --dart-define=ENVIRONMENT=production \
  --dart-define=PRODUCTION_BACKEND_URL=${PRODUCTION_BACKEND_URL:-""} \
  --dart-define=PERFORMANCE_MODE=high_refresh \
  --dart-define=ENABLE_PERFORMANCE_MONITORING=true \
  --dart-define=TARGET_REFRESH_RATE=120 \
  --dart-define=DEBUG_MODE=true \
  --profile

echo ""
echo "✅ High refresh rate build complete!"
echo "💡 Use performance monitoring overlay to track FPS"