import os
import json
from nemo.collections.asr.models import EncDecDiarLabelModel
from pathlib import Path

# ---------------- CONFIG ----------------
AUDIO_FILE = "sessions/mon/2025-08-24-1.wav"  # your WAV session
ENROLLMENTS_DIR = "enrollments"               # folder with speaker samples
OUTPUT_JSON = "sessions/mon/2025-08-24_diarization.json"
# CHUNK_LENGTH_SEC = 1800  # 30 min chunks, adjust if needed
# ---------------------------------------

# Load Sortformer model
print("Loading Sortformer model...")
diarizer = EncDecDiarLabelModel.restore_from("nemo-models/diar_msdd_telephonic.nemo")


# Prepare enrollment dictionary
enrollment_dict = {}
if os.path.isdir(ENROLLMENTS_DIR):
    for f in os.listdir(ENROLLMENTS_DIR):
        if f.lower().endswith(".wav"):
            speaker_name = os.path.splitext(f)[0]
            enrollment_dict[speaker_name] = os.path.join(ENROLLMENTS_DIR, f)
    if enrollment_dict:
        print(f"Found enrollment samples: {list(enrollment_dict.keys())}")

# Run diarization
print(f"Running diarization on {AUDIO_FILE} ...")
diarization_result = diarizer.diarize(
    audio_file=AUDIO_FILE,
    enrollment_dict=enrollment_dict,
    embedding_batch_size=8,  # adjust for your GPU
    device="cuda"
)

# Output JSON
output_data = []
for seg, label in zip(diarization_result["segments"], diarization_result["labels"]):
    start, end = seg
    output_data.append({
        "speaker": label,
        "start": float(start),
        "end": float(end)
    })

# Save JSON
os.makedirs(os.path.dirname(OUTPUT_JSON), exist_ok=True)
with open(OUTPUT_JSON, "w") as f:
    json.dump(output_data, f, indent=2)

print(f"Diarization complete! Output saved to {OUTPUT_JSON}")
