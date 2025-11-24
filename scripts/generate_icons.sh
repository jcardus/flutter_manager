ICON_NAMES="cam_caja_60,sedan_50"
OUTPUT_NAMES="truck,car"
if [ -n "$ICON_NAMES" ]; then
    counter=1
    for ICON_NAME in $(echo "$ICON_NAMES" | tr ',' ' '); do
        OUTPUT_NAME=$(echo "${OUTPUT_NAMES:-}" | cut -d',' -f"$counter")
        scripts/_generate_icons.sh "${BASE_URL}/${ICON_NAME}.php" "$OUTPUT_NAME" || exit 1
        counter=$((counter + 1))
    done
else
    echo "Warning: ICON_NAMES is not set, skipping icon generation"
fi
