#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --time=01:00:00
#SBATCH --job-name=gpu_info
#SBATCH --chdir=./
#SBATCH --mail-user=example@example.net
#SBATCH --mail-type=ALL
#SBATCH --output=slurm-%x_%j.out
#SBATCH --error=slurm-%x_%j.err

set -euo pipefail

echo "===== SLURM JOB INFO ====="
echo "Job ID: $SLURM_JOB_ID"
echo "Node list: $SLURM_NODELIST"
echo "Allocated nodes:"
mapfile -t NODES < <(scontrol show hostnames "$SLURM_NODELIST")
printf '  %s\n' "${NODES[@]}"
echo

echo "===== NVIDIA-SMI PER NODE ====="
echo

for node in "${NODES[@]}"; do
    echo "============================================================"
    echo "Node: $node"
    echo "============================================================"

    srun \
        --nodes=1 \
        --ntasks=1 \
        --ntasks-per-node=1 \
        --nodelist="$node" \
        --exact \
        bash -lc '
            echo "Hostname: $(hostname)"
            echo
            echo "--- nvidia-smi -L ---"
            nvidia-smi -L
            echo
            echo "--- nvidia-smi ---"
            nvidia-smi
        '

    echo
done

echo "===== DONE ====="