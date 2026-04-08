#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --job-name=vllm
#SBATCH --output=results/logs/ray_%J_stdout.txt
#SBATCH --error=results/logs/ray_%J_stderr.txt
#SBATCH --time=04:00:00
#SBATCH --mail-user=example@example.net
#SBATCH --mail-type=ALL
#SBATCH --chdir=

set -euo pipefail

mkdir -p results/logs
mkdir -p models
mkdir -p "$VLLM_DIR"
module purge

VLLM_DIR="${VLLM_DIR:-/scratch/$USER}"
RAY_CGRAPH_get_timeout=300
HOSTNAMES=($(scontrol show hostnames $SLURM_JOB_NODELIST))
HEAD_NODE=${HOSTNAMES[0]}

export VLLM_DIR
export RAY_CGRAPH_get_timeout
export SLURM_JOBID
export HEAD_NODE

export APPTAINER_CACHEDIR="$VLLM_DIR/.apptainer-cache"
export APPTAINER_TMPDIR="$VLLM_DIR/.apptainer-tmp"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

apptainer pull "$VLLM_DIR/vllm-openai.sif" docker://vllm/vllm-openai:latest
