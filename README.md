# distributed-llm-inference

## Overview

This project implements a distributed LLM inference system using:

- vLLM as the inference engine (OpenAI-compatible API server)
- vLLM's multiprocessing (mp) backend for multi-node pipeline parallelism coordination
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

Use this to decide which models you can run.

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

- **Multi-GPU — Tensor Parallelism (TP):**
  ```bash
  sbatch tensor_parallelism.sbatch
  ```

- **Multi-node — Pipeline Parallelism (PP) + (optional TP):**
  ```bash
  sbatch pipeline_parallelism.sbatch
  ```

---

### 5. Send Requests

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

### 6. Logs

All logs:

```
results/logs
```

---

### Notes

- Match model size to available VRAM
- Use tensor parallelism to spread a model across multiple GPUs on a single node
- Use tensor + pipeline parallelism to spread a model across multiple nodes and GPUs
- Leave VRAM headroom for runtime allocations

---

## System Description

### Current Capabilities

The system currently supports:

#### 1. Multi-node cluster on Slurm

- Slurm allocates multiple nodes
- GPU resources are correctly detected and scheduled
- Inter-node coordination is handled by vLLM's multiprocessing (mp) backend

This provides a stable distributed execution layer.

---

#### 2. vLLM inference with tensor parallelism (single node)

- vLLM is deployed inside the container environment
- Models load successfully on a single node
- Tensor parallelism is fully operational across GPUs
- GPU utilization is validated and stable

---

#### 3. Multi-node pipeline parallelism

- Model execution is split across multiple machines
- Pipeline parallelism distributes layers across nodes
- Combines with tensor parallelism for full multi-node, multi-GPU inference
- Enables running models larger than a single node's GPU memory

---

### Key Challenges

- Coordinating inter-node communication for model execution
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

- distributed test outputs
- vLLM startup and inference logs

---

### Summary

- Single-node, single-GPU inference (vLLM): complete
- Single-node, multi-GPU tensor parallelism: complete
- Multi-node tensor + pipeline parallelism: complete

The system supports full multi-node model execution.

