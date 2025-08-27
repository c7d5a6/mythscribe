#!/bin/bash

# process-segments.sh
#
# This script processes split audio files, transcribes them, and appends content
# to a single text file with speaker labels.
#
# Usage:
#   ./process-segments.sh <split_audio_dir> <output_txt_file>
#
# Example:
#   ./process-segments.sh split_output/ session.txt
#

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <split_audio_dir> <output_txt_file>"
    echo "Example: $0 split_output/ session.txt"
    exit 1
fi

SPLIT_DIR="$1"
OUTPUT_TXT="$2"

# Check if split directory exists
if [ ! -d "$SPLIT_DIR" ]; then
    echo "Error: Split audio directory '$SPLIT_DIR' not found"
    exit 1
fi

# Check if whisper CLI path is set
if [ -z "$MYTHSCRIBE_WHISPER_CLI_PATH" ]; then
    echo "Error: MYTHSCRIBE_WHISPER_CLI_PATH environment variable not set"
    exit 1
fi

# Check if whisper model path is set
if [ -z "$MYTHSCRIBE_WHISPER_MODEL_PATH" ]; then
    echo "Error: MYTHSCRIBE_WHISPER_MODEL_PATH environment variable not set"
    exit 1
fi

# Create temp directory for transcription files
TEMP_DIR="temp_transcriptions"
mkdir -p "$TEMP_DIR"

# Clear or create output text file
> "$OUTPUT_TXT"

echo "Processing split audio files from '$SPLIT_DIR'..."
echo "Output will be written to '$OUTPUT_TXT'"
echo ""

# Process each split audio file
for AUDIO_FILE in "$SPLIT_DIR"/*.wav; do
    if [ ! -f "$AUDIO_FILE" ]; then
        continue
    fi
    
    # Extract components from filename: COUNTER-SPEAKER-BASENAME.wav
    BASENAME=$(basename "$AUDIO_FILE" .wav)
    IFS='-' read -r COUNTER SPEAKER REMAINING <<< "$BASENAME"
    
    # Reconstruct the original base filename (in case it had hyphens)
    ORIGINAL_BASENAME=$(echo "$REMAINING" | sed 's/^[^-]*-//')
    
    echo "Processing: $AUDIO_FILE"
    echo "  Speaker: $SPEAKER"
    echo "  Counter: $COUNTER"
    
    # Create temp output file for this transcription
    TEMP_OUTPUT="$TEMP_DIR/temp_${COUNTER}.txt"
    
    # Transcribe the audio file
    echo "  Transcribing..."
    ${MYTHSCRIBE_WHISPER_CLI_PATH} \
        -l ru \
        -t 16 \
        -p 4 \
        --beam-size 8 \
        --best-of 8 \
        --temperature "0.0 0.2 0.4" \
        -otxt -of "$TEMP_OUTPUT" \
        -m ${MYTHSCRIBE_WHISPER_MODEL_PATH} \
        -f "$AUDIO_FILE"
    
    if [ $? -eq 0 ] && [ -f "$TEMP_OUTPUT" ]; then
        echo "  ✓ Transcription complete"
        
        # Read transcription content, remove line breaks, and append to output file
        if [ -s "$TEMP_OUTPUT" ]; then
            # Remove all line breaks and write with speaker label
            TRANSCRIPTION=$(cat "$TEMP_OUTPUT" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            echo "[${SPEAKER}]: ${TRANSCRIPTION}" >> "$OUTPUT_TXT"
            echo "  ✓ Added to output file"
        else
            echo "  ⚠ Empty transcription, skipping"
        fi
        
        # Clean up temp file
        rm "$TEMP_OUTPUT"
    else
        echo "  ✗ Transcription failed"
    fi
    
    echo ""
done

# Clean up temp directory
rmdir "$TEMP_DIR" 2>/dev/null || true

echo "Processing complete! Output written to '$OUTPUT_TXT'"
echo "Format: [SPEAKER]: transcription text without line breaks"
