#!/bin/bash
# Usage: ./convert_obs.sh <label> [date]

if [ $# -lt 1 ]; then
    echo "Usage: $0 <label> [date]"
    exit 1
fi

LABEL=$1
# If date not provided, default to today's date in YYYY-MM-DD
DATE_INPUT=${2:-}
if [ -z "$DATE_INPUT" ]; then
    DATE=$(date +%F)
else
    DATE=$DATE_INPUT
fi

OUTDIR="sessions/$LABEL"
mkdir -p "$OUTDIR"

IDX=0
for FILE in obsrecord/"$DATE"*.mp4; do
    # skip if no files found
    [ -e "$FILE" ] || continue

    IDX=$((IDX + 1))
    OUTFILE="$OUTDIR/$DATE-$IDX.wav"

    if [ -f "$OUTFILE" ]; then
        echo "Skipping $FILE → $OUTFILE (already exists)"
        continue
    fi

    echo "Converting $FILE → $OUTFILE"
    ffmpeg -i "$FILE" -ac 1 -ar 16000 -sample_fmt s16 "$OUTFILE"
done

# If no files matched, inform the user
if [ $IDX -eq 0 ]; then
    echo "No files found matching obsrecord/$DATE*.mp4"
fi

