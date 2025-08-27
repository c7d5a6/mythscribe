# mythscribe

## Overview

A pipeline for detecting speech and transcribing TTRPG game sessions. Designed to handle long-form recordings (3+ hours) with multiple speakers.

## Speech Detection Pipeline

1. **Recording**: Record TTRPG sessions using OBS (desktop sound + microphone)
2. **Conversion**: Convert OBS video/audio to WAV format using ffmpeg
   - Command: `ffmpeg -i input.mp4 -ac 1 -ar 16000 -sample_fmt s16 output.wav`
3. **Speaker Diarization**: Extract and identify individual speakers using pyannote-audio diarization
4. **Audio Segmentation**: Split audio into chunks by speaker
5. **Transcription**: Use whisper.cpp to transcribe each audio chunk with speaker labels
6. **Text Assembly**: Merge transcribed chunks into a single text file with speaker identification
7. **Summarization**: Generate summaries of the complete session

## Requirements

- obs studio [download](https://obsproject.com/download)
- ffmpeg
- jq
- cuda
- conda

### Install 
#### ffmpeg

```bash
sudo apt install ffmpeg
```

#### CUDA

```bash
sudo apt install nvidia-cuda-toolkit
nvcc --version
```

#### conda

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
chmod +x Miniconda3-latest-Linux-x86_64.sh
./Miniconda3-latest-Linux-x86_64.sh
conda --version
```

#### Whisper.cpp

```bash
git clone https://github.com/ggml-org/whisper.cpp.git
cd whisper.cpp
cmake -B build -DGGML_CUDA=1
# or for newer NVIDIA GPU's (RTX 5000 series):
# cmake -B build -DGGML_CUDA=1 -DCMAKE_CUDA_ARCHITECTURES="86"
cmake --build build -j --config Release
./models/download-ggml-model.sh large-v3 [PATH_TO_MODELS]
```

#### pyannote-audio


```bash
conda create --name pyannote-audio python==3.10.12
conda activate pyannote-audio

# conda install -c conda-forge libstdcxx-ng
# conda install pytorch==2.2.0 torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia
pip install pyannote.audio

python check.py
```

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
