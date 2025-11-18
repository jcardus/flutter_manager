#!/bin/bash

if [ -n "$ICON_NAMES" ]; then
    counter=1
    for ICON_NAME in $(echo "$ICON_NAMES" | tr ',' ' '); do
        OUTPUT_NAME=$(echo "${OUTPUT_NAMES:-}" | cut -d',' -f"$counter")
        scripts/generate_icons.sh "${BASE_URL}/${ICON_NAME}.php" "$OUTPUT_NAME" || exit 1
        counter=$((counter + 1))
    done
else
    echo "Warning: ICON_NAMES is not set, skipping icon generation"
fi

flutter pub get
flutter build ios --build-number "$BUILD_NUMBER" --config-only --no-codesign \
          --dart-define GOOGLE_MAPS_CLIENT_ID="$GOOGLE_MAPS_CLIENT_ID" \
          --dart-define GOOGLE_MAPS_SIGNING_SECRET="$GOOGLE_MAPS_SIGNING_SECRET" \
          --dart-define TRACCAR_BASE_URL="$TRACCAR_BASE_URL"
