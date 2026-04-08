#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --time=04:00:00
#SBATCH --mail-user=example@example.net
#SBATCH --mail-type=ALL
#SBATCH --job-name=vllm
#SBATCH --chdir=./
#SBATCH --output=results/logs/run_%J_stdout.txt
#SBATCH --error=results/logs/run_%J_stderr.txt

set -euo pipefail

BASE="/scratch/INSERTUSER"
SIF="$BASE/vllm-openai.sif"
MODEL_DIR="$BASE/models/Qwen3-VL-8B-Instruct"

HOST="0.0.0.0"
PORT="8000"
GPU_MEM_UTIL="0.60"
TENSOR_PARALLEL_SIZE="2"

RUNTIME_DIR="$BASE/vllm-runtime"
WORKDIR="$RUNTIME_DIR/workdir"
HOME_HOST="$RUNTIME_DIR/home"
HF_HOME_DIR="$RUNTIME_DIR/hf-home"
TMPDIR_HOST="$RUNTIME_DIR/tmp"
XDG_CACHE="$RUNTIME_DIR/xdg-cache"
XDG_CONFIG="$RUNTIME_DIR/xdg-config"
XDG_DATA="$RUNTIME_DIR/xdg-data"
TORCHINDUCTOR_CACHE="$RUNTIME_DIR/torchinductor"
TRITON_CACHE="$RUNTIME_DIR/triton"
PYTORCH_KERNEL_CACHE="$RUNTIME_DIR/torch-kernels"
APPTAINER_CACHE="$BASE/.apptainer-cache"
APPTAINER_TMP="$BASE/.apptainer-tmp"

mkdir -p \
  "$WORKDIR" \
  "$HOME_HOST" \
  "$HF_HOME_DIR/hub" \
  "$TMPDIR_HOST" \
  "$XDG_CACHE" \
  "$XDG_CONFIG" \
  "$XDG_DATA" \
  "$TORCHINDUCTOR_CACHE" \
  "$TRITON_CACHE" \
  "$PYTORCH_KERNEL_CACHE" \
  "$APPTAINER_CACHE" \
  "$APPTAINER_TMP"

if [ ! -f "$SIF" ]; then
  echo "[ERROR] Missing SIF: $SIF"
  exit 1
fi

if [ ! -d "$MODEL_DIR" ]; then
  echo "[ERROR] Missing model dir: $MODEL_DIR"
  exit 1
fi

module purge
module load CUDA/12.1.1

export APPTAINER_CACHEDIR="$APPTAINER_CACHE"
export APPTAINER_TMPDIR="$APPTAINER_TMP"

# Force every path family into /scratch/INSERTUSER via bind mounts.
export APPTAINERENV_HOME=/home/INSERTUSER
export APPTAINERENV_USER=INSERTUSER
export APPTAINERENV_LOGNAME=INSERTUSER

export APPTAINERENV_TMPDIR=/tmp
export APPTAINERENV_TMP=/tmp
export APPTAINERENV_TEMP=/tmp
export APPTAINERENV_TEMPDIR=/tmp

export APPTAINERENV_HF_HOME=/hf-home
export APPTAINERENV_HF_HUB_CACHE=/hf-home/hub
export APPTAINERENV_HUGGINGFACE_HUB_CACHE=/hf-home/hub

export APPTAINERENV_XDG_CACHE_HOME=/xdg-cache
export APPTAINERENV_XDG_CONFIG_HOME=/xdg-config
export APPTAINERENV_XDG_DATA_HOME=/xdg-data

export APPTAINERENV_TORCHINDUCTOR_CACHE_DIR=/torchinductor
export APPTAINERENV_TRITON_CACHE_DIR=/triton
export APPTAINERENV_PYTORCH_KERNEL_CACHE_PATH=/torch-kernels

export APPTAINERENV_VLLM_NO_USAGE_STATS=1

# Expose the full Slurm-assigned GPU set inside the container.
# Do NOT hardcode a single device here.
if [ -n "${CUDA_VISIBLE_DEVICES:-}" ]; then
  export APPTAINERENV_CUDA_VISIBLE_DEVICES="$CUDA_VISIBLE_DEVICES"
fi

ulimit -n 4096 || true

echo "===== JOB INFO ====="
echo "Job ID: $SLURM_JOB_ID"
echo "Hostname: $(hostname)"
echo "Working directory: $(pwd)"
echo "SIF: $SIF"
echo "Model dir: $MODEL_DIR"
echo "Tensor parallel size: $TENSOR_PARALLEL_SIZE"
echo "CUDA_VISIBLE_DEVICES: ${CUDA_VISIBLE_DEVICES:-<unset>}"
echo

echo "===== HOST GPU DIAGNOSTICS ====="
/usr/bin/nvidia-smi -L || true
/usr/bin/nvidia-smi || true
echo

echo "===== CONTAINER CUDA CHECK ====="
apptainer exec \
  --nv \
  --cleanenv \
  --containall \
  --no-mount home,cwd,tmp \
  --workdir "$WORKDIR" \
  --bind "$HOME_HOST:/home/INSERTUSER" \
  --bind "$HF_HOME_DIR:/hf-home" \
  --bind "$TMPDIR_HOST:/tmp" \
  --bind "$XDG_CACHE:/xdg-cache" \
  --bind "$XDG_CONFIG:/xdg-config" \
  --bind "$XDG_DATA:/xdg-data" \
  --bind "$TORCHINDUCTOR_CACHE:/torchinductor" \
  --bind "$TRITON_CACHE:/triton" \
  --bind "$PYTORCH_KERNEL_CACHE:/torch-kernels" \
  "$SIF" \
  python3 - <<'PY'
import os, pathlib, torch

print("torch.cuda.is_available() =", torch.cuda.is_available())
print("torch.cuda.device_count() =", torch.cuda.device_count())
if torch.cuda.is_available():
    for i in range(torch.cuda.device_count()):
        print(f"device{i} = {torch.cuda.get_device_name(i)}")

print("\nENV:")
for k in [
    "HOME","TMPDIR","TMP","TEMP","TEMPDIR",
    "HF_HOME","HF_HUB_CACHE","HUGGINGFACE_HUB_CACHE",
    "XDG_CACHE_HOME","XDG_CONFIG_HOME","XDG_DATA_HOME",
    "TORCHINDUCTOR_CACHE_DIR","TRITON_CACHE_DIR",
    "PYTORCH_KERNEL_CACHE_PATH",
    "CUDA_VISIBLE_DEVICES",
]:
    print(f"{k}={os.environ.get(k)}")

print("\nWRITE TESTS:")
for p in [
    "/home/INSERTUSER",
    "/tmp",
    "/hf-home",
    "/xdg-cache",
    "/xdg-config",
    "/xdg-data",
    "/torchinductor",
    "/triton",
    "/torch-kernels",
]:
    path = pathlib.Path(p)
    path.mkdir(parents=True, exist_ok=True)
    t = path / ".write_test"
    t.write_text("ok")
    print("writable:", t)
PY
echo

echo "===== STARTING VLLM ====="
exec apptainer exec \
  --nv \
  --cleanenv \
  --containall \
  --no-mount home,cwd,tmp \
  --workdir "$WORKDIR" \
  --bind "$HOME_HOST:/home/INSERTUSER" \
  --bind "$MODEL_DIR:/model:ro" \
  --bind "$HF_HOME_DIR:/hf-home" \
  --bind "$TMPDIR_HOST:/tmp" \
  --bind "$XDG_CACHE:/xdg-cache" \
  --bind "$XDG_CONFIG:/xdg-config" \
  --bind "$XDG_DATA:/xdg-data" \
  --bind "$TORCHINDUCTOR_CACHE:/torchinductor" \
  --bind "$TRITON_CACHE:/triton" \
  --bind "$PYTORCH_KERNEL_CACHE:/torch-kernels" \
  "$SIF" \
  vllm serve /model \
    --host "$HOST" \
    --port "$PORT" \
    --gpu-memory-utilization "$GPU_MEM_UTIL" \
    --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
    --max-model-len 8192