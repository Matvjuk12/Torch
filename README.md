# Torch Programming Language

**Torch** is a compiled programming language that combines Python's ultimate simplicity with C++/CUDA-level performance and automatic parallelization for CPU+GPU systems.

**Slogan:** *Python development speed. C++ execution speed. Zero annotations.*

  
*Licensed under MIT or Apache 2.0 (dual license). See LICENSE files.*

***

## Introduction

In today's computing landscape, Python dominates scientific computing, machine learning, and prototyping due to its extreme syntax simplicity and rich ecosystem. However, its performance in general-purpose and high-throughput computations remains **20–100x slower** than C/C++/Rust, forcing developers to rewrite performance-critical sections in low-level languages or use cumbersome hybrid solutions (Cython, CUDA Python, etc.).

Existing "fast Python" attempts like **Mojo**, **Julia**, and **CuPy** are either interpreted/partially JIT-compiled, require explicit parallelization annotations, or remain in alpha stages (Mojo as of late 2025).

**The world lacks a programming language with these key properties:**
1. Syntax no more complex than Python
2. C/C++ performance on CPU and CUDA on GPU
3. **Fully automatic parallelization** without programmer annotations

The topic's relevance is confirmed by the explosion of AI compute demands and the absence of languages bridging this development-performance gap.

## Research Goal

Create **Torch** — a compiled language delivering Python-level code simplicity while achieving performance comparable to hand-optimized C/C++/CUDA.

## Key Tasks

1. **Minimalist syntax**: Strictly typed (type inference) simpler than Python
2. **Torch → LLVM + NVIDIA PTX compiler** with aggressive vectorization, parallelization, and GPU offloading
3. **Polyhedral loop analysis** with automatic OpenMP/OpenMP-Offload/CUDA kernel insertion (no programmer involvement)
4. Achieve **≥80%** performance of hand-optimized C/C++/CUDA in real AI workloads

**Research object**: Static compilation and automatic parallelization systems  
**Research subject**: Automatic transformation of high-level sequential code into efficient parallel code for CPU+GPU heterogeneous systems

## Current Implementation Status

### 1. Frontend & Syntax
Torch syntax is intentionally **simpler than Python**:
```
fn main() {
    let t = tensor<f32,[3,4]>((1,2,3,4),(5,6,7,8),(9,10,11,12));
    let res = matmul(t, t.T());
    print(res);
}
```
- **No mandatory indentation** (uses `{}` braces like C/Rust)
- **No explicit type declarations** (MLIR/HM-style inference)
- **Built-in tensors** with static shapes

### 2. Compiler Pipeline: Torch → MLIR → LLVM + PTX

**Key innovation**: 3-level polyhedral optimizer:

**Level 1 (LoopNest)**: Automatic parallel/vectorizable loop detection using ISL  
**Level 2 (TensorFlow)**: Tensor expression → computation graph with fusion (TVM/XLA-style)  
**Level 3 (GPU Offload)**: CUDA kernel generation using Polly heuristics + MCMC autotuning of tile sizes

## Example Syntax

```torch
fn matmul(a: tensor<f32,[m,k]>, b: tensor<f32,[k,n]>) -> tensor<f32,[m,n]> {
    let mut res = tensor<f32,[m,n]>((0,));
    for i in 0..m {
        for j in 0..n {
            let mut sum = 0.0f32;
            for k in 0..k {  // Auto-vectorized + GPU offload
                sum += a[i,k] * b[k,j];
            }
            res[i,j] = sum;
        }
    }
    res
}
```

## Expected Results

Torch will be **the first language worldwide** combining:
- Python syntax simplicity
- Performance **exceeding** hand-written C/C++/CUDA
- **Zero parallelization annotations**

## Timeline

- **ANTLR4 grammar**: ✅ Complete
- **Type inference**: In progress
- **MLIR frontend**: Q2 2026
- **Polyhedral optimizer**: Q4 2026
- **Torch v1.0**: **Spring 2028**

***

## Authors

**Zhukovsky M.A.**  
*7th grade student, robotics engineer, physicist, mathematician, astronomer*  
**Supervisor**: Kravchenko D.V. (Computer Science Teacher)  
**Scientific Supervisor**: Kravchenko D.V. (Computer Science Teacher)  

**MBOU Lyceum, Lesosibirsk**

***

**⭐ Star this repo if you want Python-speed development with C++-speed execution!**  
**🐛 Issues/PRs welcome for the polyhedral optimizer!**

***

*Licensed under [MIT](LICENSE-MIT.txt) or [Apache 2.0](LICENSE-APACHE.txt) at your option.*
