#!/bin/bash
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --job-name=ray_test
#SBATCH --output=results/logs/ray_%J_stdout.txt
#SBATCH --error=results/logs/ray_%J_stderr.txt
#SBATCH --time=00:20:00
#SBATCH --mail-user=example@example.net
#SBATCH --mail-type=ALL
#SBATCH --chdir=./

set -euo pipefail

mkdir -p results/logs

module purge
module load CUDA/12.1.1
module load Python || module load python/anaconda3

VENV=".venv-ray"

if [ ! -d "$VENV" ]; then
    python -m venv "$VENV"
fi

source "$VENV/bin/activate"

pip install -r requirements.txt

# Config: expected Ray cluster size.
EXPECTED_RAY_NODES=2

# Determine nodes assigned by Slurm
mapfile -t NODES < <(scontrol show hostnames "$SLURM_JOB_NODELIST")
ALLOCATED_NODES="${#NODES[@]}"

if [ "$ALLOCATED_NODES" -lt "$EXPECTED_RAY_NODES" ]; then
    echo "ERROR: Expected at least $EXPECTED_RAY_NODES allocated nodes, but got $ALLOCATED_NODES"
    exit 1
fi

HEAD_NODE="${NODES[0]}"

# Collect IPs for all allocated nodes
declare -A NODE_IPS
for NODE in "${NODES[@]}"; do
    NODE_IPS["$NODE"]=$(
        srun --quiet -N1 -n1 -w "$NODE" bash --noprofile --norc -c 'hostname -I | awk "{print \$1}"'
    )
done

HEAD_IP="${NODE_IPS[$HEAD_NODE]}"
export RAY_ADDRESS="${HEAD_IP}:6379"
export EXPECTED_RAY_NODES

echo "Nodes allocated:"
for NODE in "${NODES[@]}"; do
    echo "  $NODE (${NODE_IPS[$NODE]})"
done
echo "Ray head: $HEAD_NODE ($HEAD_IP)"
echo "Expected Ray nodes: $EXPECTED_RAY_NODES"

# Start Ray head
srun --overlap -N1 -n1 -w "$HEAD_NODE" bash --noprofile --norc -c "
source $VENV/bin/activate
ray start --head --node-ip-address=$HEAD_IP --port=6379 --disable-usage-stats --block
" &

sleep 5

# Start Ray workers on all remaining nodes
for NODE in "${NODES[@]:1}"; do
    NODE_IP="${NODE_IPS[$NODE]}"
    echo "Starting Ray worker on $NODE ($NODE_IP)"

    srun --overlap -N1 -n1 -w "$NODE" bash --noprofile --norc -c "
source $VENV/bin/activate
ray start --address=$RAY_ADDRESS --node-ip-address=$NODE_IP --disable-usage-stats --block
" &
done

sleep 10

# Run Python driver on head node
srun --overlap -N1 -n1 -w "$HEAD_NODE" bash --noprofile --norc -c "
source $VENV/bin/activate
export RAY_ADDRESS=$RAY_ADDRESS
export EXPECTED_RAY_NODES=$EXPECTED_RAY_NODES
python ray_ping.py
"