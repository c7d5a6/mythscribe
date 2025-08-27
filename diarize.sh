#!/bin/bash

# Ask for number of speakers
read -p "Enter number of speakers: " N_SPEAKERS
if [ -n "$N_SPEAKERS" ]; then
  echo "  Number of speakers: $N_SPEAKERS"
else
  echo "  Number of speakers not provided"
  exit 1
fi

python pya-diarize.py /path/in.wav /path/out.json --num-speakers $N_SPEAKERS --enroll-dir $MYTHSCRIBE_PYANNOTE_ENROLLMENT_DIR