import json
import argparse
from pathlib import Path
import re


def find_best_speaker_match(token_start, token_end, speakers, token_text):
    """Find the best speaker match using overlap and proximity"""
    best_speaker = None
    best_score = float('inf')
    
    for segment in speakers['segments']:
        speaker_start = segment['start']
        speaker_end = segment['end']
        speaker_name = segment['speaker']
        
        # Check if token overlaps with speaker segment
        overlap_start = max(token_start, speaker_start)
        overlap_end = min(token_end, speaker_end)
        
        if overlap_end > overlap_start:
            # There's overlap - use overlap duration as score (higher is better)
            overlap_duration = overlap_end - overlap_start
            score = -overlap_duration  # Negative so lower is better
        else:
            # No overlap - use distance to nearest edge
            if token_end < speaker_start:
                distance = speaker_start - token_end
            else:
                distance = token_start - speaker_end
            score = distance
        
        if score < best_score:
            best_score = score
            best_speaker = speaker_name
    
    return best_speaker


def process_transcription(speakers_file, transcript_file, output_file):
    """Process transcription with enhanced speaker matching"""
    
    with open(speakers_file, 'r', encoding='utf-8') as f:
        speakers = json.load(f)
    
    with open(transcript_file, 'r', encoding='utf-8') as f:
        transcript = json.load(f)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        speaker = None
        
        for segment in transcript['transcription']:
            f.write(f".")
            segment_start = segment['offsets']['from'] / 1000.0 
            segment_end = segment['offsets']['to'] / 1000.0
            # token_length = (segment_end-segment_start)/len(segment['tokens'])
            # Split text into words by whitespace and punctuation
            words = re.findall(r"\w+|[^\w\s]", segment['text'], re.UNICODE)
            token_length = (segment_end - segment_start) / max(1, len(words))


            # Process tokens
            for i, word in enumerate(words):
                
                token_start = segment_start + i*token_length #+0.4
                token_end = segment_start + (i+1)*token_length #+0.4
                
                # Find best speaker for this token
                token_speaker = find_best_speaker_match(token_start, token_end, speakers, word)

                if token_speaker != speaker:
                    speaker = token_speaker
                    f.write(f"\n[{speaker}]: ")
                
                f.write(f" {word}")



def process_whisperx_segments(speakers_file, segments, output_file):
    """Process WhisperX-aligned segments (list of dicts) with per-word timestamps.

    segments: List of { 'start': float, 'end': float, 'text': str, 'words': [ { 'word': str, 'start': float, 'end': float, ... }, ... ] }
    """
    # Load speakers diarization JSON
    with open(speakers_file, 'r', encoding='utf-8') as f:
        speakers = json.load(f)

    with open(output_file, 'a', encoding='utf-8') as f:
        current_speaker = None

        for seg in segments:
            words = seg.get('words') or []
            for w in words:
                token_start = w.get('start')
                token_end = w.get('end')
                token_text = str(w.get('word', ''))
                if not token_text:
                    continue

                # Find best speaker for this token
                token_speaker = find_best_speaker_match(token_start, token_end, speakers, token_text)

                if token_speaker != current_speaker:
                    current_speaker = token_speaker
                    f.write(f"\n[{current_speaker}]: ")

                f.write(f" {token_text}")



def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Speaker diarization: provide input audio and output file path"
    )
    parser.add_argument("speakers", help="Path to speakers.json file")
    parser.add_argument("transcript", help="Path to transcript.json file")
    parser.add_argument("output", help="Output path (.txt)")

    return parser.parse_args()



def main() -> int:
    args = parse_args()
    segments = json.load(open(args.transcript, 'r', encoding='utf-8'))
    process_whisperx_segments(args.speakers, segments, args.output)

if __name__ == "__main__":
    main()