#!/bin/bash
set -e
set +u
source $(conda info --json | awk '/conda_prefix/ { gsub(/"|,/, "", $2); print $2 }')/bin/activate /home/luciano/miniconda3/envs/bremiss
set -u
python3 -c "import dipy; print(dipy.__version__)"
