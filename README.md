# mythscribe

## Overview

A pipeline for detecting speech and transcribing TTRPG game sessions. Designed to handle long-form recordings (3+ hours) with multiple speakers.

## Speech Detection Pipeline

1. **Recording**: Record TTRPG sessions using OBS (desktop sound + microphone)
2. **Conversion**: Convert OBS video/audio to WAV format using ffmpeg
   - Command: `ffmpeg -i input.mp4 -ac 1 -ar 16000 -sample_fmt s16 output.wav`
3. **Speaker Diarization**: Extract and identify individual speakers using NeMo diarization
4. **Audio Segmentation**: Split audio into chunks by speaker
5. **Transcription**: Use whisper.cpp to transcribe each audio chunk with speaker labels
6. **Text Assembly**: Merge transcribed chunks into a single text file with speaker identification
7. **Summarization**: Generate summaries of the complete session

## Requirements

- ffmpeg

## Symbolic links

This folders contains real data with recording, transcribes and temporary data

- obsrecord
- sessions
- transcribe

## Convert audio

```bash
./convert_obs.sh
```

Converts obs recording from "obsrecord" into the "sessions" audiofiles.
