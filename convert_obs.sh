#!/bin/bash
# Usage: ./convert_obs.sh <label> [date]

if [ $# -lt 1 ]; then
    echo "Usage: $0 <label> [date]"
    exit 1
fi

LABEL=$1
DATE_INPUT=${2:-}
if [ -z "$DATE_INPUT" ]; then
    DATE=$(date +%F)
else
    DATE=$DATE_INPUT
fi

OUTDIR="sessions/$LABEL"
mkdir -p "$OUTDIR"

CHUNK_MINUTES=30
CHUNK_SECONDS=$((CHUNK_MINUTES * 60))

IDX=0
for FILE in obsrecord/"$DATE"*.mp4; do
    [ -e "$FILE" ] || continue

    BASENAME=$(basename "$FILE" .mp4)
    echo "Processing $FILE"

    TMPFILE="$OUTDIR/$BASENAME-temp.wav"
    ffmpeg -y -i "$FILE" -ac 1 -ar 16000 -sample_fmt s16 \
      -af "highpass=f=80, dynaudnorm=f=150:g=15, loudnorm=I=-24:LRA=7:TP=-2" \
      "$TMPFILE"

    # Get total duration in seconds (rounded down)
    FILE_DURATION=$(ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$TMPFILE" | cut -d'.' -f1)

    CHUNK_IDX=0
    while [ $((CHUNK_IDX * CHUNK_SECONDS)) -lt "$FILE_DURATION" ]; do
        OUTFILE="$OUTDIR/${DATE}-$(printf "%03d" $((IDX+1))).wav"

        ffmpeg -y -i "$TMPFILE" \
            -ss $((CHUNK_IDX * CHUNK_SECONDS)) \
            -t $CHUNK_SECONDS \
            -c copy "$OUTFILE" -loglevel error

        echo "  Created chunk: $OUTFILE"

        IDX=$((IDX + 1))
        CHUNK_IDX=$((CHUNK_IDX + 1))
    done

    rm -f "$TMPFILE"
done

if [ $IDX -eq 0 ]; then
    echo "No files found matching obsrecord/$DATE*.mp4"
fi
