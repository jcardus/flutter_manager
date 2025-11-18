flutter pub get
flutter build $1 \
          --build-number "$BUILD_NUMBER" \
          --dart-define GOOGLE_MAPS_CLIENT_ID="$GOOGLE_MAPS_CLIENT_ID" \
          --dart-define GOOGLE_MAPS_SIGNING_SECRET="$GOOGLE_MAPS_SIGNING_SECRET" \
          --dart-define TRACCAR_BASE_URL="https://traccar-eu.fleetmap.pt"
