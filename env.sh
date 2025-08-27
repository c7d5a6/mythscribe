#!/bin/bash
# Project environment variables. Copy and adjust as needed.

export MYTHSCRIBE_WHISPER_CLI_PATH="/home/c7d5a6/projects/whisper.cpp/build/bin/whisper-cli"
export MYTHSCRIBE_WHISPER_MODEL_DIR="/home/c7d5a6/Music/mythscribe/whisper-models"
export MYTHSCRIBE_WHISPER_MODEL_PATH="${MYTHSCRIBE_WHISPER_MODEL_DIR}/ggml-large-v3.bin"

export MYTHSCRIBE_PYANNOTE_ENROLLMENT_DIR="/home/c7d5a6/Music/mythscribe/pyannote/enrollments"

conda activate nemo