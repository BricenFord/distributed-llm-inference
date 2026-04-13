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

CLUSTER_TOTAL_MIB=0
CLUSTER_USED_MIB=0
CLUSTER_FREE_MIB=0

declare -A NODE_TOTAL_MIBS
declare -A NODE_USED_MIBS
declare -A NODE_FREE_MIBS

echo "===== NVIDIA-SMI PER NODE ====="
echo

for node in "${NODES[@]}"; do
    echo "============================================================"
    echo "Node: $node"
    echo "============================================================"

    NODE_REPORT="$(
        srun \
            --nodes=1 \
            --ntasks=1 \
            --ntasks-per-node=1 \
            --nodelist="$node" \
            --exact \
            bash -lc '
                set -euo pipefail

                echo "Hostname: $(hostname)"
                echo
                echo "--- nvidia-smi -L ---"
                nvidia-smi -L
                echo
                echo "--- nvidia-smi ---"
                nvidia-smi
                echo
                echo "--- structured memory summary ---"

                nvidia-smi \
                  --query-gpu=index,name,memory.total,memory.used,memory.free \
                  --format=csv,noheader,nounits |
                awk -F, '"'"'
                    BEGIN {
                        node_total=0
                        node_used=0
                        node_free=0
                        printf "%3s  %-30s %10s %10s %10s\n", "GPU", "Name", "TotalMiB", "UsedMiB", "FreeMiB"
                    }
                    {
                        idx=$1
                        name=$2
                        total=$3
                        used=$4
                        free=$5

                        gsub(/^[ \t]+|[ \t]+$/, "", idx)
                        gsub(/^[ \t]+|[ \t]+$/, "", name)
                        gsub(/^[ \t]+|[ \t]+$/, "", total)
                        gsub(/^[ \t]+|[ \t]+$/, "", used)
                        gsub(/^[ \t]+|[ \t]+$/, "", free)

                        printf "%3s  %-30s %10d %10d %10d\n", idx, substr(name,1,30), total, used, free

                        node_total += total
                        node_used  += used
                        node_free  += free
                    }
                    END {
                        printf "\nNODE_SUMMARY total_mib=%d used_mib=%d free_mib=%d\n", node_total, node_used, node_free
                    }
                '"'"'
            '
    )"

    echo "$NODE_REPORT"
    echo

    NODE_SUMMARY_LINE="$(echo "$NODE_REPORT" | grep 'NODE_SUMMARY' || true)"
    if [ -z "$NODE_SUMMARY_LINE" ]; then
        echo "[ERROR] Missing NODE_SUMMARY for $node"
        exit 1
    fi

    NODE_TOTAL_MIB="$(echo "$NODE_SUMMARY_LINE" | sed -n 's/.*total_mib=\([0-9]\+\).*/\1/p')"
    NODE_USED_MIB="$(echo "$NODE_SUMMARY_LINE"  | sed -n 's/.*used_mib=\([0-9]\+\).*/\1/p')"
    NODE_FREE_MIB="$(echo "$NODE_SUMMARY_LINE"  | sed -n 's/.*free_mib=\([0-9]\+\).*/\1/p')"

    NODE_TOTAL_MIBS["$node"]="$NODE_TOTAL_MIB"
    NODE_USED_MIBS["$node"]="$NODE_USED_MIB"
    NODE_FREE_MIBS["$node"]="$NODE_FREE_MIB"

    CLUSTER_TOTAL_MIB=$((CLUSTER_TOTAL_MIB + NODE_TOTAL_MIB))
    CLUSTER_USED_MIB=$((CLUSTER_USED_MIB + NODE_USED_MIB))
    CLUSTER_FREE_MIB=$((CLUSTER_FREE_MIB + NODE_FREE_MIB))
done

echo "===== AGGREGATED VRAM SUMMARY ====="
printf "%-20s %15s %15s %15s\n" "Scope" "TotalGiB" "UsedGiB" "FreeGiB"

for node in "${NODES[@]}"; do
    NODE_TOTAL_MIB="${NODE_TOTAL_MIBS[$node]}"
    NODE_USED_MIB="${NODE_USED_MIBS[$node]}"
    NODE_FREE_MIB="${NODE_FREE_MIBS[$node]}"

    NODE_TOTAL_GIB="$(awk "BEGIN {printf \"%.2f\", $NODE_TOTAL_MIB / 1024}")"
    NODE_USED_GIB="$(awk "BEGIN {printf \"%.2f\", $NODE_USED_MIB / 1024}")"
    NODE_FREE_GIB="$(awk "BEGIN {printf \"%.2f\", $NODE_FREE_MIB / 1024}")"

    printf "%-20s %15s %15s %15s\n" "$node" "$NODE_TOTAL_GIB" "$NODE_USED_GIB" "$NODE_FREE_GIB"
done

CLUSTER_TOTAL_GIB="$(awk "BEGIN {printf \"%.2f\", $CLUSTER_TOTAL_MIB / 1024}")"
CLUSTER_USED_GIB="$(awk "BEGIN {printf \"%.2f\", $CLUSTER_USED_MIB / 1024}")"
CLUSTER_FREE_GIB="$(awk "BEGIN {printf \"%.2f\", $CLUSTER_FREE_MIB / 1024}")"

printf "%-20s %15s %15s %15s\n" "ALL_NODES" "$CLUSTER_TOTAL_GIB" "$CLUSTER_USED_GIB" "$CLUSTER_FREE_GIB"
echo
echo "Approx total AVAILABLE VRAM across allocated nodes: ${CLUSTER_FREE_GIB} GiB"
echo "===== DONE ====="