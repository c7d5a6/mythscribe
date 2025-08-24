#!/bin/bash
# Usage: ./convert_obs.sh <label>

if [ $# -lt 1 ]; then
    echo "Usage: $0 <label>"
    exit 1
fi

LABEL=$1
OUTDIR="sessions/$LABEL"
mkdir -p "$OUTDIR"

for FILE in obsrecord/*.mp4; do
    # skip if no files found
    [ -e "$FILE" ] || continue

    BASENAME=$(basename "$FILE" .mp4)
    DATE=${BASENAME%% *}       # take date before first space
    OUTFILE="$OUTDIR/$DATE.wav"

    if [ -f "$OUTFILE" ]; then
        echo "Skipping $FILE → $OUTFILE (already exists)"
        continue
    fi

    echo "Converting $FILE → $OUTFILE"
    ffmpeg -i "$FILE" -ac 1 -ar 16000 -sample_fmt s16 "$OUTFILE"
done

