#!/bin/bash
# Usage: ./transcribe.sh <input_file> <output_file> <start_time> <end_time>

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input_file> <output_file>"
    exit 1
fi

. env.sh

INPUT_FILE=$1
OUTPUT_FILE=$2
# START_TIME_IN_SECONDS=$3
# END_TIME_IN_SECONDS=$4
# DURATION_IN_SECONDS=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${INPUT_FILE}")

# # Convert to ms and subtract 2900 (2.9s)
# DURATION_IN_MILLISECONDS=$(awk -v DURATION="${DURATION_IN_SECONDS}" 'BEGIN { printf "%d\n", (DURATION * 1000) - 2900 }')
# DURATION_IN_MILLISECONDS=$(awk -v DURATION="${DURATION_IN_SECONDS}" 'BEGIN {
#     val = (DURATION * 1000) - 2900;
#     if (val < 0) val = 0;
#     printf "%d\n", val;
# }')

# echo "Duration in milliseconds (minus 2.9s): ${DURATION_IN_MILLISECONDS}"

# # Convert float seconds to integer milliseconds
# START_TIME_IN_MILLISECONDS=$(awk -v s="$START_TIME_IN_SECONDS" 'BEGIN { printf "%d", s * 1000 }')
# END_TIME_IN_MILLISECONDS=$(awk -v s="$END_TIME_IN_SECONDS" 'BEGIN { printf "%d", s * 1000 }')
# DURATION_IN_MILLISECONDS=$((END_TIME_IN_MILLISECONDS - START_TIME_IN_MILLISECONDS))

# Transcribe with whisper.cpp
${MYTHSCRIBE_WHISPER_CLI_PATH} -ot 1000 \
    -l ru \
    -t 1 \
    -p 1 \
    --beam-size 1 \
    --best-of 1 \
    --temperature "0.0 0.4 0.8" \
    -ojf -of ${OUTPUT_FILE} \
    -m ${MYTHSCRIBE_WHISPER_MODEL_PATH} \
    -f ${INPUT_FILE}
