# distributed-llm-inference

## Overview

This project implements a distributed LLM inference system using:

- vLLM as the inference engine (OpenAI-compatible API server)
- Ray for cluster orchestration across nodes
- Slurm for multi-node resource allocation on an HPC cluster
- Apptainer for reproducible containerized execution

The system is designed to serve large language models that exceed single-node GPU memory limits by distributing execution across multiple GPUs and machines.

---

## Usage

This outlines the current workflow for running inference jobs on the cluster.
Make sure you modify the configuration in each of the files before running them.

---

### 1. Check GPU VRAM

Determine available GPU memory per node:

```bash
sbatch gpu-info-vram.sbatch
```

Use this to decide which model you can run.

---

### 2. Pull vLLM Container

```bash
sbatch pull_vllm_container.sbatch
```

This prepares the Apptainer environment with vLLM and dependencies.

---

### 3. Download Model

Choose a model based on available VRAM, then edit `pull_HF_model.sbatch` with the model name and run:

```bash
sbatch pull_HF_model.sbatch
```

---

### 4. Run Inference

- **Single GPU:**
  ```bash
  sbatch run_vllm.sbatch
  ```

- **Multi-GPU (tensor parallelism):**
  ```bash
  sbatch tensor_parallelism.sbatch
  ```

---

### 5. Multi-node with Ray (Integration is in progress.)

For multi-node jobs:

- allocate nodes with Slurm  
- start Ray head on the primary node  
- workers join automatically

---

### 6. Send Requests

vLLM exposes an OpenAI-compatible API:

```
http://<host>:8000/v1
```

Example:

```bash
curl http://<host>:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<model>",
    "prompt": "Hello",
    "max_tokens": 50
  }'
```

---

### 7. Logs

All logs:

```
results/logs
```

---

### Notes

- Match model size to available VRAM  
- Use parallelism for larger models  
- Leave VRAM headroom for runtime allocations  


---

## System Description

### Current Capabilities

The system currently supports:

#### 1. Multi-node Ray cluster on Slurm

- Slurm allocates multiple nodes
- A Ray head node is launched on the primary node
- Worker nodes join automatically
- The cluster is validated via distributed test execution
- GPU resources are correctly detected and scheduled

This provides a stable distributed execution layer.

---

#### 2. vLLM inference with tensor parallelism (single node)

- vLLM is deployed inside the container environment
- Models load successfully on a single node
- Tensor parallelism is fully operational across GPUs
- GPU utilization is validated and stable

At this stage, single-node multi-GPU inference is working reliably.

---

### Current Focus

The main objective now is:

## Multi-node pipeline parallelism

The goal is to extend inference beyond a single node by:

- splitting model execution across multiple machines
- coordinating execution using Ray
- leveraging pipeline parallelism to distribute layers across nodes

This is required to:

- run models larger than a single node’s GPU memory
- efficiently utilize distributed GPU resources
- handle real-world HPC constraints (e.g., shared nodes, variable GPU availability)

---

### Key Challenges

- Coordinating inter-node communication for model execution  
- Integrating Ray scheduling with vLLM’s distributed mechanisms  
- Managing GPU memory fragmentation across nodes  
- Ensuring stable startup and synchronization across Slurm jobs  
- Allocating and distributing model shards across GPUs that are already partially in use (handling contention and dynamic memory availability)

---

### Execution Environment

All jobs run inside Apptainer containers to ensure:

- consistent dependencies across nodes
- reproducibility
- compatibility with HPC environments

---

### Logs and Outputs

Logs are written to:

```
results/logs
```

These include:

- Ray cluster initialization logs  
- distributed test outputs  
- vLLM startup and inference logs  

---

### Summary

- Ray cluster on Slurm: complete  
- Single-node tensor parallelism (vLLM): complete  
- Multi-node pipeline parallelism: in progress  

The system is now focused on enabling full multi-node model execution.
