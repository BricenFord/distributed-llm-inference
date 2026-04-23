#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --job-name=download_model
#SBATCH --output=results/logs/download_model_%J_stdout.txt
#SBATCH --error=results/logs/download_model_%J_stderr.txt
#SBATCH --time=04:00:00
#SBATCH --mail-user=example@example.net
#SBATCH --mail-type=ALL
#SBATCH --chdir=./

set -euo pipefail

mkdir -p results/logs
mkdir -p models
module purge

# Configurable base directory
VLLM_DIR="${VLLM_DIR:-/scratch/$USER}"
mkdir -p "$VLLM_DIR"
export VLLM_DIR

# Model configuration
MODEL_REPO="${MODEL_REPO:-URL}" # Insert hugging face url
MODEL_NAME="${MODEL_NAME:-MODEL_NAME}" # Insert model name
MODEL_PARENT="${MODEL_PARENT:-$VLLM_DIR/models}"
MODEL_DIR="${MODEL_DIR:-$MODEL_PARENT/$MODEL_NAME}"

export MODEL_REPO
export MODEL_NAME
export MODEL_PARENT
export MODEL_DIR

HOSTNAMES=($(scontrol show hostnames "$SLURM_JOB_NODELIST"))
HEAD_NODE=${HOSTNAMES[0]}
export SLURM_JOBID
export HEAD_NODE

echo "[INFO] Job ID: $SLURM_JOBID"
echo "[INFO] Head node: $HEAD_NODE"
echo "[INFO] VLLM_DIR: $VLLM_DIR"
echo "[INFO] MODEL_REPO: $MODEL_REPO"
echo "[INFO] MODEL_PARENT: $MODEL_PARENT"
echo "[INFO] MODEL_DIR: $MODEL_DIR"

mkdir -p "$MODEL_PARENT"
cd "$MODEL_PARENT"

if ! command -v git >/dev/null 2>&1; then
  echo "[ERROR] git is not available."
  echo "[ERROR] Load it with your module system first."
  exit 1
fi

if ! command -v git-lfs >/dev/null 2>&1; then
  echo "[ERROR] git-lfs is not available."
  echo "[ERROR] Try one of these first:"
  echo "[ERROR]   module avail git-lfs"
  echo "[ERROR]   module load git-lfs"
  exit 1
fi

echo "[INFO] Initializing git-lfs..."
git lfs install --skip-repo

if [ -d "$MODEL_DIR/.git" ]; then
  echo "[INFO] Existing clone found. Updating..."
  cd "$MODEL_DIR"
  git pull --ff-only
  git lfs pull
else
  echo "[INFO] Cloning model repo..."
  git clone "$MODEL_REPO" "$MODEL_NAME"
  cd "$MODEL_DIR"
  git lfs pull
fi

echo "[INFO] Verifying download..."
du -sh "$MODEL_DIR" || true
find "$MODEL_DIR" -maxdepth 1 -type f | sed 's#^#  #'

echo "[SUCCESS] Model is at:"
echo "  $MODEL_DIR"
