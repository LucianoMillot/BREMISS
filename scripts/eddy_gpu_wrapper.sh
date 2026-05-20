#!/bin/bash
# Wrapper to automatically assign a free GPU to eddy_cuda
# Uses a lock file to prevent conflicts between parallel jobs

LOCK_DIR="/tmp/eddy_gpu_locks"
mkdir -p "$LOCK_DIR"

# Try each GPU in order, take the first available
for gpu_id in 0 1; do
    lockfile="$LOCK_DIR/gpu_${gpu_id}.lock"
    # flock -n : non-blocking, fails if already locked
    exec 9>"$lockfile"
    if flock -n 9; then
        export CUDA_VISIBLE_DEVICES=$gpu_id
        echo "[eddy_gpu_wrapper] Assigned GPU ${gpu_id} (PID $$)"
        # Launch eddy_cuda with all arguments passed to the wrapper
        eddy_cuda "$@"
        exit_code=$?
        flock -u 9
        exit $exit_code
    fi
done

# No free GPU available, fall back to GPU 0
echo "[eddy_gpu_wrapper] No GPU lock available, falling back to GPU 0"
export CUDA_VISIBLE_DEVICES=0
eddy_cuda "$@"
