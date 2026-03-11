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

# Get nodes from Slurm
NODES=$(scontrol show hostnames $SLURM_JOB_NODELIST)
HEAD_NODE=$(echo $NODES | awk '{print $1}')
WORKER_NODE=$(echo $NODES | awk '{print $2}')

# Get IP of head node
HEAD_IP=$(srun -N1 -n1 -w $HEAD_NODE hostname -I | awk '{print $1}')

export RAY_ADDRESS="$HEAD_IP:6379"

# Start Ray head
srun --overlap -N1 -n1 -w $HEAD_NODE bash -c "
source $VENV/bin/activate
ray start --head --node-ip-address=$HEAD_IP --port=6379 --disable-usage-stats --block
" &

sleep 5

# Start Ray worker
srun --overlap -N1 -n1 -w $WORKER_NODE bash -c "
source $VENV/bin/activate
ray start --address=$RAY_ADDRESS --disable-usage-stats --block
" &

sleep 10

# Run Python test
srun --overlap -N1 -n1 -w $HEAD_NODE bash -c "
source $VENV/bin/activate
export RAY_ADDRESS=$RAY_ADDRESS
python ray_ping.py
"