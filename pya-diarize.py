#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

from pyannote.audio import Pipeline, Model, Inference
from pyannote.core import Segment
import torch
from torch.nn import functional as F
from collections import Counter, defaultdict
from scipy.optimize import linear_sum_assignment
import numpy as np

import warnings
warnings.filterwarnings("ignore", message=".*deprecated.*", category=UserWarning)
warnings.filterwarnings("ignore", message=".*will be removed.*", category=UserWarning)

# Load environment variables
load_dotenv()
HF_TOKEN = os.getenv("HF_TOKEN")
if not HF_TOKEN:
    print("Error: HF_TOKEN not found in environment variables", file=sys.stderr)
    sys.exit(1)


def write_json(annotation, mapping, out_path: str) -> None:
    """Write annotation to JSON, remapping speaker numbers to enrolled labels if provided."""
    segments = []
    for segment, _, speaker in annotation.itertracks(yield_label=True):
        mapped_speaker = mapping.get(speaker, speaker)
        segments.append(
            {
                "start": float(segment.start),
                "end": float(segment.end),
                "speaker": str(mapped_speaker),
            }
        )
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"segments": segments}, f, ensure_ascii=False, indent=2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Speaker diarization with optional enrollment mapping"
    )
    parser.add_argument("audio", help="Path to input audio file (e.g., WAV/MP3)")
    parser.add_argument("output", help="Output path (.json for JSON)")
    parser.add_argument(
        "--num-speakers",
        type=int,
        default=None,
        help="If known, fix the number of speakers (integer)",
    )
    parser.add_argument(
        "--enroll-dir",
        default=None,
        help="Directory containing enrollment wav/flac/mp3 files; file name (without extension) is used as speaker label",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    # Allow TF32 for faster GPU computations
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True

    audio_path = Path(args.audio)
    if not audio_path.exists():
        print(f"Input audio not found: {audio_path}", file=sys.stderr)
        return 1

    try:
        pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            use_auth_token=HF_TOKEN,
        )
    except Exception as exc:
        print(f"Failed to load pipeline: {exc}", file=sys.stderr)
    pipeline.to(torch.device("cuda"))
    print("Pipeline loaded and sent to GPU")

    # Build inputs and options for diarization
    pipeline_input = {"audio": str(audio_path)}

    try:
        N = int(args.num_speakers)
        annotation = pipeline(pipeline_input, min_speakers=N, max_speakers=N+3)
        print("Diarization completed with fixed number of speakers")
    except Exception as exc:
        print(f"Diarization failed: {exc}", file=sys.stderr)
        return 3

    # If no enrollment, just dump raw annotation
    if not args.enroll_dir:
        write_json(annotation, {}, args.output)
        return 0
    else:
        write_json(annotation, {}, "temp_diarize.json")

    enroll_dir = Path(args.enroll_dir)
    if not enroll_dir.exists() or not enroll_dir.is_dir():
        print(f"Enrollment directory not found: {enroll_dir}", file=sys.stderr)
        return 4

    # Load embedding model
    try:
        emb_model = Model.from_pretrained("pyannote/embedding", use_auth_token=HF_TOKEN)
    except Exception as exc:
        print(f"Failed to load embedding model: {exc}", file=sys.stderr)
        return 5

    inference = Inference(emb_model, window="whole")
    inference.to(torch.device("cuda"))
    print("Inference model sent to device cuda")

    # Prepare enrolled embeddings
    supported_ext = {".wav", ".flac", ".mp3", ".m4a", ".ogg"}
    enrolled: dict[str, torch.Tensor] = {}
    for entry in sorted(enroll_dir.iterdir()):
        if entry.is_file() and entry.suffix.lower() in supported_ext:
            name = entry.stem
            try:
                emb_np = inference(entry.absolute())
            except Exception as exc:
                print(f"Skip enrollment '{name}' ({entry.absolute()}): {exc}", file=sys.stderr)
                continue
            emb_t = torch.tensor(emb_np, dtype=torch.float32)
            enrolled[name] = emb_t

    if not enrolled:
        print(f"No enrollment audio found in {enroll_dir}", file=sys.stderr)
        return 6

    # Step 1: compute best label per segment
    votes: dict[str, list[str]] = defaultdict(list)  # speaker_num -> list of best enrolled labels
    for segment, _, speaker_num in annotation.itertracks(yield_label=True):
        try:
            MIN_LEN = 0.5  # seconds
            duration = segment.end - segment.start
            if duration < MIN_LEN:
                center = (segment.start + segment.end) / 2
                new_start = max(0, center - MIN_LEN / 2)
                new_end = center + MIN_LEN / 2
                segment = Segment(new_start, new_end)
            seg_emb_np = inference.crop(str(audio_path), segment)
        except Exception as exc:
            print(f"Failed to embed segment {segment}: {exc}", file=sys.stderr)
            continue
        seg_emb = torch.tensor(seg_emb_np, dtype=torch.float32)

        best_label = None
        best_score = None
        for label, ref_emb in enrolled.items():
            score = F.cosine_similarity(seg_emb.unsqueeze(0), ref_emb.unsqueeze(0)).item()
            if best_score is None or score > best_score:
                best_score = score
                best_label = label

        if best_label:
            votes[speaker_num].append(best_label)

    # Step 2: determine final mapping per speaker_num
    # Step 2: determine final mapping per speaker_num using Hungarian algorithm
    speaker_nums = list(votes.keys())
    enroll_labels = list(enrolled.keys())

    # Build cost matrix: rows = diarized speakers, cols = enrolled labels
    cost_matrix = np.zeros((len(speaker_nums), len(enroll_labels)))

    for i, speaker_num in enumerate(speaker_nums):
        # Embedder votes distribution
        counts = Counter(votes[speaker_num])
        for j, label in enumerate(enroll_labels):
            # Use negative frequency as "cost" (Hungarian minimizes cost)
            cost_matrix[i, j] = -counts[label]

    # Run Hungarian assignment
    row_ind, col_ind = linear_sum_assignment(cost_matrix)
    
    mapping: dict[str, str] = {}
    for i, j in zip(row_ind, col_ind):
        mapping[speaker_nums[i]] = enroll_labels[j]

    # Any diarized speakers not assigned (more speakers than enrollments) -> fallback
    for speaker_num in speaker_nums:
        if speaker_num not in mapping:
            mapping[speaker_num] = speaker_num  # keep original numeric ID


    print("Speaker mapping:")
    for k, v in mapping.items():
        print(f"  {k} -> {v}")

    # Step 3: write JSON with remapped speakers
    write_json(annotation, mapping, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
