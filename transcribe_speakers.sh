#!/bin/bash
# Usage: ./transcribe_segments.sh <input_file> <speakers.json> <output_file>
#
# Example:
#   ./transcribe_segments.sh session.wav speakers.json transcript.txt

set -euo pipefail

if [ $# -ne 3 ]; then
    echo "Usage: $0 <input_file> <speakers.json> <output_file>"
    exit 1
fi

INPUT_FILE="$1"
JSON_FILE="$2"
OUTPUT_FILE="$3"

# Check inputs
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    exit 1
fi
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file '$JSON_FILE' not found"
    exit 1
fi

# Require jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq not installed"
    exit 1
fi

# Prepare output file
> "$OUTPUT_FILE"

# Parse diarization segments
SEGMENTS=$(jq -r '.segments[] | "\(.start)|\(.end)|\(.speaker)"' "$JSON_FILE")

COUNTER=1

echo "Transcribing segments from $INPUT_FILE using $JSON_FILE..."
echo "Writing transcript to $OUTPUT_FILE"
echo ""

# Loop over segments
echo "$SEGMENTS" | while IFS='|' read -r start end speaker; do
    if [ -n "$start" ] && [ -n "$end" ] && [ -n "$speaker" ]; then
        echo "Segment $COUNTER: ${start}s - ${end}s (${speaker})"

        TEMP_OUT="temp_transcript_${COUNTER}"

        # Call your whisper wrapper with start/end times
        ./transcribe.sh "$INPUT_FILE" "$TEMP_OUT" "$start" "$end"

        if [ -f "${TEMP_OUT}.txt" ]; then
            # Flatten to one line and prepend speaker
            PROCESSED_TEXT=$(tr '\n' ' ' < "${TEMP_OUT}.txt" | sed "s/^/[${speaker}]: /")
            echo "$PROCESSED_TEXT" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            rm -f "${TEMP_OUT}.txt"
        else
            echo "  ✗ No transcript generated for segment $COUNTER"
        fi

        COUNTER=$((COUNTER + 1))
    fi
done

echo ""
echo "Done! Transcript saved at $OUTPUT_FILE"
