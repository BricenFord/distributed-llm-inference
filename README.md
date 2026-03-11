# distributed-llm-inference

This project explores running large language model inference across multiple nodes on an HPC cluster managed by Slurm.

The goal is to build a system where a model can run across GPUs on several machines. The work is being done step-by-step so that each layer of the system can be verified before moving on to the next.

## Project overview

The stack being built looks like this:

```txt
Slurm
  ↓
Ray cluster
  ↓
vLLM inference engine
  ↓
Distributed model execution across GPUs
```

Each stage is brought online independently so issues can be isolated and debugged easily.

## Current progress

### Phase 1 – Ray on Slurm

The first step is getting a Ray cluster running inside a Slurm allocation.

The workflow for this stage is:

1. Request multiple nodes with Slurm
2. Start a Ray head node on the first machine
3. Start Ray workers on the remaining machines
4. Wait until the cluster reports all nodes as active
5. Run a small distributed test program

The goal here is to confirm that:

- nodes can discover each other
- Ray can schedule work across machines
- GPU resources are visible
- the Slurm workflow behaves as expected

Once this works consistently, the distributed runtime foundation is in place.

### Phase 2 – Running vLLM

After Ray is working, the next step is introducing vLLM.

This phase will focus on:

- installing vLLM in the cluster environment
- running inference on a single node
- confirming that models load correctly
- verifying GPU utilization

This step confirms the inference engine works correctly before adding multi-node complexity.

### Phase 3 – Multi-node vLLM inference

The final stage is running a model across multiple nodes.

This will involve combining Ray orchestration with vLLM's distributed capabilities so that model execution can be split across GPUs on different machines.

Possible parallelization approaches include:

- tensor parallelism
- pipeline parallelism

The goal is to support models larger than the memory available on a single node.

## Typical workflow

Submit the Ray test job with:

```bash
sbatch ray.sbatch
```

Once the job starts, the script will:

1. load the required modules
2. prepare a Python virtual environment
3. start the Ray cluster
4. wait for the nodes to register
5. run the distributed test script

Logs are written to:

```txt
results/logs
```

## Next steps

Planned next steps include:

1. installing vLLM
2. running inference locally on a single node
3. integrating vLLM with the Ray cluster
4. experimenting with multi-node model parallelization

For now, the focus is on getting Ray working reliably under Slurm before moving on to distributed inference.