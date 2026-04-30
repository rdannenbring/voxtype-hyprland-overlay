#!/bin/bash
# Generate default beep sounds using ffmpeg
# Run this once after cloning, or replace the WAV files with your own.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found"; exit 1; }

ffmpeg -y -f lavfi -i "sine=frequency=880:duration=0.3" \
    -af "afade=t=out:st=0.2:d=0.1" \
    "$SCRIPT_DIR/beep-start.wav" -loglevel quiet

ffmpeg -y -f lavfi -i "sine=frequency=660:duration=0.2" \
    -af "afade=t=out:st=0.1:d=0.1" \
    "$SCRIPT_DIR/beep-stop.wav" -loglevel quiet

echo "Generated beep-start.wav and beep-stop.wav"
