#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --time=2:00:00
#SBATCH --mail-user=example@example.net
#SBATCH --mail-type=ALL
#SBATCH --job-name=vllm
#SBATCH --chdir=./
#SBATCH --output=results/logs/run_%J_%N_stdout.txt
#SBATCH --error=results/logs/run_%J_%N_stderr.txt

#SBATCH --nodelist=

set -euo pipefail

BASE="/scratch/INSERTUSER"
SIF="$BASE/vllm-openai.sif"
MODEL_DIR="$BASE/models/INSERTMODEL"

HOST="0.0.0.0"
PORT="8000"
GPU_MEM_UTIL="0.80"
TENSOR_PARALLEL_SIZE="2"
PIPELINE_PARALLEL_SIZE="2"
NNODES="2"
MASTER_PORT="29501"

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

if [ -n "${CUDA_VISIBLE_DEVICES:-}" ]; then
  export APPTAINERENV_CUDA_VISIBLE_DEVICES="$CUDA_VISIBLE_DEVICES"
fi

ulimit -n 4096 || true

MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)

echo "===== JOB INFO ====="
echo "Job ID: $SLURM_JOB_ID"
echo "Node list: $SLURM_JOB_NODELIST"
echo "Master addr: $MASTER_ADDR"
echo "Working directory: $(pwd)"
echo "SIF: $SIF"
echo "Model dir: $MODEL_DIR"
echo "Tensor parallel size: $TENSOR_PARALLEL_SIZE"
echo "Pipeline parallel size: $PIPELINE_PARALLEL_SIZE"
echo "CUDA_VISIBLE_DEVICES: ${CUDA_VISIBLE_DEVICES:-<unset>}"
echo

echo "===== HOST GPU DIAGNOSTICS ====="
srun --ntasks=2 --ntasks-per-node=1 bash -lc '
  echo "---- $(hostname) ----"
  /usr/bin/nvidia-smi -L || true
  /usr/bin/nvidia-smi || true
  echo
'
echo

echo "===== CONTAINER CUDA CHECK ====="
srun --ntasks=2 --ntasks-per-node=1 apptainer exec \
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
import os, pathlib, socket, torch

print("HOSTNAME =", socket.gethostname())
print("SLURM_NODEID =", os.environ.get("SLURM_NODEID"))
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
    "CUDA_VISIBLE_DEVICES","SLURM_NODEID"
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
exec srun --ntasks=2 --ntasks-per-node=1 bash -lc '
  NODE_RANK="${SLURM_NODEID}"
  echo "Launching on $(hostname) with NODE_RANK=${NODE_RANK}"

  COMMON_ARGS=(
    /model
    --host "'"$HOST"'"
    --port "'"$PORT"'"
    --gpu-memory-utilization "'"$GPU_MEM_UTIL"'"
    --tensor-parallel-size "'"$TENSOR_PARALLEL_SIZE"'"
    --pipeline-parallel-size "'"$PIPELINE_PARALLEL_SIZE"'"
    --distributed-executor-backend mp
    --nnodes "'"$NNODES"'"
    --node-rank "${NODE_RANK}"
    --master-addr "'"$MASTER_ADDR"'"
    --master-port "'"$MASTER_PORT"'"
    --max-model-len 262144
    --enable-auto-tool-choice
    --tool-call-parser qwen3_coder
  )

  if [ "${NODE_RANK}" = "0" ]; then
    echo "Rank 0: starting API server"
    exec apptainer exec \
      --nv \
      --cleanenv \
      --containall \
      --no-mount home,cwd,tmp \
      --workdir "'"$WORKDIR"'" \
      --bind "'"$HOME_HOST"':/home/INSERTUSER" \
      --bind "'"$MODEL_DIR"':/model:ro" \
      --bind "'"$HF_HOME_DIR"':/hf-home" \
      --bind "'"$TMPDIR_HOST"':/tmp" \
      --bind "'"$XDG_CACHE"':/xdg-cache" \
      --bind "'"$XDG_CONFIG"':/xdg-config" \
      --bind "'"$XDG_DATA"':/xdg-data" \
      --bind "'"$TORCHINDUCTOR_CACHE"':/torchinductor" \
      --bind "'"$TRITON_CACHE"':/triton" \
      --bind "'"$PYTORCH_KERNEL_CACHE"':/torch-kernels" \
      "'"$SIF"'" \
      vllm serve "${COMMON_ARGS[@]}"
  else
    echo "Rank 1: starting headless follower"
    exec apptainer exec \
      --nv \
      --cleanenv \
      --containall \
      --no-mount home,cwd,tmp \
      --workdir "'"$WORKDIR"'" \
      --bind "'"$HOME_HOST"':/home/INSERTUSER" \
      --bind "'"$MODEL_DIR"':/model:ro" \
      --bind "'"$HF_HOME_DIR"':/hf-home" \
      --bind "'"$TMPDIR_HOST"':/tmp" \
      --bind "'"$XDG_CACHE"':/xdg-cache" \
      --bind "'"$XDG_CONFIG"':/xdg-config" \
      --bind "'"$XDG_DATA"':/xdg-data" \
      --bind "'"$TORCHINDUCTOR_CACHE"':/torchinductor" \
      --bind "'"$TRITON_CACHE"':/triton" \
      --bind "'"$PYTORCH_KERNEL_CACHE"':/torch-kernels" \
      "'"$SIF"'" \
      vllm serve "${COMMON_ARGS[@]}" --headless
  fi
'
