#!/bin/bash
# split-file.sh
#
# This script splits a file into multiple files based on the JSON output from pya-diarize.py.
#
# Usage:
#   ./split-file.sh <input_file> <speakers.json> <output_dir>
#
# Example:
#   ./split-file.sh input.wav speakers.json output_dir
#

set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <input_file> <speakers.json> <output_dir>"
    echo "Example: $0 input.wav speakers.json output_dir"
    exit 1
fi

INPUT_FILE="$1"
JSON_FILE="$2"
OUTPUT_DIR="$3"

# Check if input files exist
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file '$JSON_FILE' not found"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get the base filename without extension
BASE_FILENAME=$(basename "$INPUT_FILE" | sed 's/\.[^.]*$//')

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    exit 1
fi

# Check if ffmpeg is available
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is required but not installed. Please install ffmpeg first."
    exit 1
fi

# Get file duration in seconds (float)
FILE_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")

echo "Splitting '$INPUT_FILE' based on '$JSON_FILE'..."
echo "Output directory: '$OUTPUT_DIR'"
echo "Base filename: '$BASE_FILENAME'"
echo "File duration: $FILE_DURATION s"
echo ""

# Parse JSON and extract segments with proper handling of speaker names with spaces
SEGMENTS=$(jq -r '.segments[] | "\(.start)|\(.end)|\(.speaker)"' "$JSON_FILE")

# Counter for numbering
COUNTER=1

# Process each segment
echo "$SEGMENTS" | while IFS='|' read -r start end speaker; do
    if [ -n "$start" ] && [ -n "$end" ] && [ -n "$speaker" ]; then
        # Adjust times
        start=$(awk -v s="$start" 'BEGIN { v=s-2.0; if (v<0) v=0; printf "%.3f", v }')
        end=$(awk -v e="$end" -v d="$FILE_DURATION" 'BEGIN { v=e+0.9; if (v>d) v=d; printf "%.3f", v }')

        # Sanitize speaker name for filename (replace spaces with underscores)
        SAFE_SPEAKER=$(echo "$speaker" | tr ' ' '_')
        
        # Format the output filename: number-name-originalfilename
        OUTPUT_FILENAME="${COUNTER}-${SAFE_SPEAKER}-${BASE_FILENAME}.wav"
        OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_FILENAME"
        
        echo "Segment $COUNTER: ${start}s - ${end}s (${speaker}) -> $OUTPUT_FILENAME"
        
        # Use ffmpeg to extract the segment with proper WAV audio parameters
        ffmpeg -i "$INPUT_FILE" \
            -ss "$start" -to "$end" \
            -ac 1 -ar 16000 -sample_fmt s16 \
            "$OUTPUT_PATH" -y -loglevel error
        
        if [ $? -eq 0 ]; then
            echo "  ✓ Created: $OUTPUT_FILENAME"
        else
            echo "  ✗ Failed to create: $OUTPUT_FILENAME"
        fi
        
        COUNTER=$((COUNTER + 1))
    fi
done

echo ""
echo "Splitting complete! Output files are in '$OUTPUT_DIR'"
echo "Total segments processed: $((COUNTER - 1))"
