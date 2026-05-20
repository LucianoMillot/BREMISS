#!/bin/bash
# Wrapper pour assigner automatiquement un GPU libre à eddy_cuda
# Utilise un fichier lock pour éviter les conflits entre jobs parallèles

LOCK_DIR="/tmp/eddy_gpu_locks"
mkdir -p "$LOCK_DIR"

# Essaie chaque GPU dans l'ordre, prend le premier disponible
for gpu_id in 0 1; do
    lockfile="$LOCK_DIR/gpu_${gpu_id}.lock"
    # flock -n : non-bloquant, échoue si déjà verrouillé
    exec 9>"$lockfile"
    if flock -n 9; then
        export CUDA_VISIBLE_DEVICES=$gpu_id
        echo "[eddy_gpu_wrapper] Assigned GPU ${gpu_id} (PID $$)"
        # Lance eddy_cuda avec tous les arguments passés au wrapper
        eddy_cuda "$@"
        exit_code=$?
        flock -u 9
        exit $exit_code
    fi
done

# Aucun GPU libre disponible, attend et utilise GPU 0 par défaut
echo "[eddy_gpu_wrapper] No GPU lock available, falling back to GPU 0"
export CUDA_VISIBLE_DEVICES=0
eddy_cuda "$@"
