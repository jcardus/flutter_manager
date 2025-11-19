scripts/generate_icons.sh
flutter pub get
flutter build ios --build-number "$BUILD_NUMBER" --config-only --no-codesign \
          --dart-define GOOGLE_MAPS_CLIENT_ID="$GOOGLE_MAPS_CLIENT_ID" \
          --dart-define GOOGLE_MAPS_SIGNING_SECRET="$GOOGLE_MAPS_SIGNING_SECRET" \
          --dart-define TRACCAR_BASE_URL="$TRACCAR_BASE_URL"
