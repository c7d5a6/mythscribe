import whisperx
import gc
import torch
import argparse
import json

device = "cuda"
audio_file = "audio.wav"
batch_size = 32 # reduce if low on GPU mem
compute_type = "float16" # change to "int8" if low on GPU mem (may reduce accuracy)

parser = argparse.ArgumentParser(
    description="Speaker diarization: provide input audio and output file path"
)
parser.add_argument("input", help="Input path (.wav)")
parser.add_argument("output", help="Output path (.json)")
args = parser.parse_args()
output_file = args.output
input_file = args.input

# 1. Transcribe with original whisper (batched)
model = whisperx.load_model("large-v3", device, compute_type=compute_type)

# save model to local path (optional)
# model_dir = "/path/"
# model = whisperx.load_model("large-v2", device, compute_type=compute_type, download_root=model_dir)

audio = whisperx.load_audio(input_file)
result = model.transcribe(audio, batch_size=batch_size)
print(result["segments"]) # before alignment

# delete model if low on GPU resources
gc.collect(); torch.cuda.empty_cache(); del model

# 2. Align whisper output
model_a, metadata = whisperx.load_align_model(language_code="ru", device=device)
result = whisperx.align(result["segments"], model_a, metadata, audio, device, return_char_alignments=False)

print(result["segments"]) # after alignment



with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(result["segments"], f, ensure_ascii=False, indent=4)


gc.collect(); torch.cuda.empty_cache(); del model_a
