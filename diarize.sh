#!/bin/bash

. env.sh

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

INPUT_FILE=$1
# Ask for number of speakers
read -p "Enter number of speakers: " N_SPEAKERS
if [ -n "$N_SPEAKERS" ]; then
  echo "  Number of speakers: $N_SPEAKERS"
else
  echo "  Number of speakers not provided"
  exit 1
fi

python pya-diarize.py "$INPUT_FILE" "speakers.json" --num-speakers $N_SPEAKERS --enroll-dir $MYTHSCRIBE_PYANNOTE_ENROLLMENT_DIR