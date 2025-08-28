#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

from pyannote.audio import Pipeline, Model, Inference
import torch
from torch.nn import functional as F

# Load environment variables
load_dotenv()
HF_TOKEN = os.getenv("HF_TOKEN")
if not HF_TOKEN:
    print("Error: HF_TOKEN not found in environment variables", file=sys.stderr)
    sys.exit(1)

def write_json(annotation, out_path: str) -> None:
    segments = []
    for segment, _, speaker in annotation.itertracks(yield_label=True):
        segments.append(
            {
                "start": float(segment.start),
                "end": float(segment.end),
                "speaker": str(speaker),
            }
        )
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"segments": segments}, f, ensure_ascii=False, indent=2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Speaker diarization: provide input audio and output file path"
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
            use_auth_token=HF_TOKEN
        )
    except Exception as exc:
        print(f"Failed to load pipeline: {exc}", file=sys.stderr)
    pipeline.to(torch.device("cuda"))
    print("Pipeline loaded and sent to GPU")

    # Build inputs and options for diarization
    pipeline_input = {"audio": str(audio_path)}

    # Enrollment from directory will be handled via embedding reassignment below

    try:
        if args.num_speakers is not None:
            annotation = pipeline(pipeline_input, num_speakers=int(args.num_speakers))
            print("Diarization completed with fixed number of speakers")
            print(annotation)
        else:
            annotation = pipeline(pipeline_input)
    except Exception as exc:
        print(f"Diarization failed: {exc}", file=sys.stderr)
        return 3

    # If an enrollment directory is provided, post-process with embeddings to assign closest speaker
    if args.enroll_dir:
        enroll_dir = Path(args.enroll_dir)
        if not enroll_dir.exists() or not enroll_dir.is_dir():
            print(f"Enrollment directory not found: {enroll_dir}", file=sys.stderr)
            return 4

        # Load embedding model and create inference helper
        try:
            emb_model = Model.from_pretrained("pyannote/embedding",
                use_auth_token=HF_TOKEN
            )
        except Exception as exc:
            print(f"Failed to load embedding model: {exc}", file=sys.stderr)
            return 5

        inference = Inference(emb_model, window="whole")
        inference.to(torch.device("cuda"))
        print("Inference model sent to device cuda")

        # Prepare enrolled speaker embeddings from all audio files in the directory
        supported_ext = {".wav", ".flac", ".mp3", ".m4a", ".ogg"}
        enrolled: dict[str, torch.Tensor] = {}
        for entry in sorted(enroll_dir.iterdir()):
            if entry.is_file() and entry.suffix.lower() in supported_ext:
                name = entry.stem
                try:
                    emb_np = inference(entry.absolute())  # numpy array
                except Exception as exc:
                    print(f"Skip enrollment '{name}' ({entry.absolute()}): {exc}", file=sys.stderr)
                    continue
                emb_t = torch.tensor(emb_np, dtype=torch.float32)
                enrolled[name] = emb_t

        if not enrolled:
            print(f"No enrollment audio found in {enroll_dir}", file=sys.stderr)
            return 6

        # Reassign labels by closest cosine similarity per segment
        reassigned = []
        for segment, _, _ in annotation.itertracks(yield_label=True):
            try:
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

            reassigned.append({
                "start": float(segment.start),
                "end": float(segment.end),
                "speaker": str(best_label) if best_label is not None else "unknown",
                "score": float(best_score) if best_score is not None else None,
            })

        # Write reassigned segments as JSON
        out_path = Path(args.output)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({"segments": reassigned}, f, ensure_ascii=False, indent=2)
    else:
        out_path = Path(args.output)
        write_json(annotation, str(out_path))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())