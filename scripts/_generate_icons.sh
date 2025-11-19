#!/bin/bash

BASE_URL="${1}"
ICON_OUTPUT_NAME="${2:-truck}"
COLORS="${3:-green:34C759,gray:b2b2b2,red:FF3B30}"
START_ANGLE="${4:-0}"
END_ANGLE="${5:-360}"
STEP="${6:-22.5}"

OUTPUT_DIR="assets/map/icons/"

mkdir -p "$OUTPUT_DIR"
if [ "$BASE_URL" == "" ]; then
    echo "Please set BASE_URL"
    exit 1
fi

if ! command -v rsvg-convert &> /dev/null; then
    echo "Error: librsvg is not installed."
    echo "Please install it using: brew install librsvg"
    exit 1
fi

# Split colors by comma
IFS=',' read -ra COLOR_ARRAY <<< "$COLORS"

echo "Configuration:"
echo "  Output name: $ICON_OUTPUT_NAME"
echo "  Colors: $COLORS"
echo "  Start angle: $START_ANGLE"
echo "  End angle: $END_ANGLE"
echo "  Step: $STEP"
echo ""

# Calculate total number of images per color
images_per_color=$(echo "scale=0; (($END_ANGLE - $START_ANGLE) / $STEP) + 1" | bc)
total_colors=${#COLOR_ARRAY[@]}
total_images=$(echo "$images_per_color * $total_colors" | bc)

# Global counter for progress
global_count=0

# Loop through each color
for COLOR_SPEC in "${COLOR_ARRAY[@]}"; do
    # Trim whitespace
    COLOR_SPEC=$(echo "$COLOR_SPEC" | xargs)

    # Split color name and hex code by colon
    IFS=':' read -r COLOR_NAME COLOR_HEX <<< "$COLOR_SPEC"

    # If no colon found, use the whole string as both name and hex
    if [ -z "$COLOR_HEX" ]; then
        COLOR_HEX="$COLOR_NAME"
    fi

    echo ""
    echo "========================================="
    echo "Processing color: $COLOR_NAME ($COLOR_HEX)"
    echo "========================================="
    echo ""

    # Loop through angles with configurable step
    angle=$START_ANGLE
    while (( $(echo "$angle < $END_ANGLE" | bc -l) ))
    do
        global_count=$((global_count + 1))

        # Format filename with padded numbers for proper sorting
        svg_filename=$(printf "${ICON_OUTPUT_NAME}_%05.1f.svg" "$angle")
        png_filename=$(printf "${ICON_OUTPUT_NAME}_${COLOR_NAME}_%05.1f.png" "$angle")

        echo "[$global_count/$total_images] Color: $COLOR_NAME | Angle: $angle -> $png_filename"

        # Download the SVG image using hex code
        URL="${BASE_URL}?grados=${angle}&c=${COLOR_HEX}&b=F0F0F0"
        echo "$URL"
        curl -s "${URL}" -o "${svg_filename}"

        # Convert SVG to PNG with transparency
        rsvg-convert "${svg_filename}" -o "${OUTPUT_DIR}/${png_filename}"
        rm "${svg_filename}"

        # Increment angle
        angle=$(echo "$angle + $STEP" | bc)
    done
done

echo ""
echo "========================================="
echo "Download and conversion complete!"
echo "========================================="
echo "Total images downloaded: $total_images"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Color directories created:"
for COLOR_SPEC in "${COLOR_ARRAY[@]}"; do
    COLOR_SPEC=$(echo "$COLOR_SPEC" | xargs)
    IFS=':' read -r COLOR_NAME COLOR_HEX <<< "$COLOR_SPEC"
    if [ -z "$COLOR_HEX" ]; then
        COLOR_HEX="$COLOR_NAME"
    fi
    echo "  - ${OUTPUT_DIR}/${COLOR_NAME}/ (hex: $COLOR_HEX)"
done
