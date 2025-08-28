#!/bin/bash
# Usage: ./transcribe.sh <input_file> <output_file> <start_time> <end_time>

if [ $# -lt 4 ]; then
    echo "Usage: $0 <input_file> <output_file> <start_time> <end_time>"
    exit 1
fi

. env.sh

INPUT_FILE=$1
OUTPUT_FILE=$2
START_TIME_IN_SECONDS=$3
END_TIME_IN_SECONDS=$4

# Convert float seconds to integer milliseconds
START_TIME_IN_MILLISECONDS=$(awk -v s="$START_TIME_IN_SECONDS" 'BEGIN { printf "%d", s * 1000 }')
END_TIME_IN_MILLISECONDS=$(awk -v s="$END_TIME_IN_SECONDS" 'BEGIN { printf "%d", s * 1000 }')
DURATION_IN_MILLISECONDS=$((END_TIME_IN_MILLISECONDS - START_TIME_IN_MILLISECONDS))

# Transcribe with whisper.cpp
${MYTHSCRIBE_WHISPER_CLI_PATH} \
	-np \
	-sow \
    -l ru \
    -t 16 \
    -p 4 \
    -ot ${START_TIME_IN_MILLISECONDS} \
    -d ${DURATION_IN_MILLISECONDS} \
    --beam-size 8 \
    --best-of 8 \
    --temperature "0.0 0.1 0.2" \
    -otxt -of ${OUTPUT_FILE} \
    -m ${MYTHSCRIBE_WHISPER_MODEL_PATH} \
    -f ${INPUT_FILE}
