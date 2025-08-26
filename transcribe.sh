#!/bin/bash
# Usage: ./transcribe.sh <input_file> <output_file>

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input_file> <output_file>"
    exit 1
fi

INPUT_FILE=$1
OUTPUT_FILE=$2

${MYTHSCRIBE_WHISPER_CLI_PATH} \
	-l ru \
	-t 16 \
	-p 4 \
	--beam-size 8 \
	--best-of 8 \
	--temperature "0.0 0.2 0.4" \
	-otxt -of ${OUTPUT_FILE} \
	-m ${MYTHSCRIBE_WHISPER_MODEL_PATH} \
	-f ${INPUT_FILE}