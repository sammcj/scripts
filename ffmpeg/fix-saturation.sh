#!/usr/bin/env bash
set -euo pipefail

SATURATION="0.85"
GAMMA_R="0.98"
GAMMA_B="1.02"
PROCESSED_COUNT=0
SKIPPED_COUNT=0
MAX_JOBS=2  # One job per GPU

echo "Starting batch processing:"
echo "  Saturation: $SATURATION"
echo "  Gamma Red: $GAMMA_R (reduce warmth)"
echo "  Gamma Blue: $GAMMA_B (add coolness)"
echo "  Using $MAX_JOBS NVIDIA GPUs in parallel"
echo ""

# Function to process a single file
process_file() {
  local file="$1"
  local gpu_id="$2"
  local output="${file%.mkv}-fixed.mkv"
  local backup="${file%.mkv}-pre-processing.mkv"
  local logfile
  logfile="gpu${gpu_id}-$(date +%s).log"


  echo "[GPU $gpu_id] Processing: $file" | tee -a "$logfile"

  # Extract video bitrate from original file
  bitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file" || echo "")

  # Use fallback bitrate if not detected
  if [[ -z "$bitrate" ]] || [[ "$bitrate" == "N/A" ]]; then
    echo "[GPU $gpu_id]   ⚠ Could not detect bitrate, using 8000k default" | tee -a "$logfile"
    bitrate_kbps=8000
  else
    bitrate_kbps=$((bitrate / 1000))
  fi

  maxrate_kbps=$((bitrate_kbps + (bitrate_kbps / 10)))
  bufsize_kbps=$((bitrate_kbps * 2))

  echo "[GPU $gpu_id]   Target bitrate: ${bitrate_kbps}k (maxrate: ${maxrate_kbps}k)" | tee -a "$logfile"

  # Process with NVIDIA hardware acceleration on specific GPU
  # Redirect output to log file to avoid interleaving
  if ffmpeg -hwaccel cuda -hwaccel_device $gpu_id -i "$file" \
    -vf "eq=saturation=$SATURATION:gamma_r=$GAMMA_R:gamma_b=$GAMMA_B" \
    -c:v h264_nvenc -gpu $gpu_id -preset p7 \
    -b:v "${bitrate_kbps}k" \
    -maxrate "${maxrate_kbps}k" \
    -bufsize "${bufsize_kbps}k" \
    -profile:v high -level 4.0 \
    -c:a copy -c:s copy \
    -map 0 \
    "$output" 2>&1 | grep -E "frame=|speed=" | tee -a "$logfile"; then

    # Processing successful - rename files
    echo "[GPU $gpu_id] ✓ Encoding completed successfully" | tee -a "$logfile"
    echo "[GPU $gpu_id]   Renaming original to: $backup" | tee -a "$logfile"
    mv "$file" "$backup"

    echo "[GPU $gpu_id]   Renaming processed to: $file" | tee -a "$logfile"
    mv "$output" "$file"

    echo "[GPU $gpu_id] ✓ Completed: $file" | tee -a "$logfile"
    echo "[GPU $gpu_id]   Original (now backup): $(du -h "$backup" | cut -f1)" | tee -a "$logfile"
    echo "[GPU $gpu_id]   Processed (now active): $(du -h "$file" | cut -f1)" | tee -a "$logfile"
  else
    echo "[GPU $gpu_id] ✗ Error processing $file - keeping original file unchanged" | tee -a "$logfile"
  fi

  rm -f "$logfile"
  echo ""
}

# Collect files to process
files_to_process=()
for file in *.mkv; do
  [[ -e "$file" ]] || continue

  # Skip test files, samples, backup files and already processed files
  if [[ "$file" == test-sat-*.mkv ]] || \
     [[ "$file" == *-fixed.mkv ]] || \
     [[ "$file" == *-pre-processing.mkv ]] || \
     [[ "$file" == sample.mkv ]] || \
     [[ "$file" == preview.mkv ]]; then
    continue
  fi

  output="${file%.mkv}-fixed.mkv"

  if [[ -f "$output" ]]; then
    echo "Skipping $file (output already exists)"
    ((SKIPPED_COUNT++))
    continue
  fi

  files_to_process+=("$file")
done

echo "Found ${#files_to_process[@]} files to process"
echo ""

# Process files in parallel, 2 at a time (one per GPU)
gpu_id=0
for file in "${files_to_process[@]}"; do
  # Wait if we have MAX_JOBS running
  while [[ $(jobs -r | wc -l) -ge $MAX_JOBS ]]; do
    sleep 1
  done

  # Process file in background on specific GPU
  process_file "$file" $gpu_id &

  # Rotate to next GPU
  gpu_id=$(( (gpu_id + 1) % MAX_JOBS ))

  # Brief pause to ensure jobs start
  sleep 0.5
done

# Show active jobs
echo "Active encoding jobs:"
jobs -l

# Wait for all background jobs to complete
wait

# Count completed files
PROCESSED_COUNT=${#files_to_process[@]}

echo ""
echo "================================"
echo "Batch processing complete!"
echo "Files processed: $PROCESSED_COUNT"
echo "Files skipped: $SKIPPED_COUNT"
echo "================================"
echo ""
echo "Original files renamed with -pre-processing suffix"
echo "Processed files now have the original filenames"
