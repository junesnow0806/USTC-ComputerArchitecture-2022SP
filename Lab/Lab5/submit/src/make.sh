#!/bin/bash
cd CPU-part
gcc MatMul_basic.c -o baseline
gcc MatMul_AVX.c -mavx -mavx2 -mfma -msse -msse2 -msse3 -o avx
gcc MatMul_AVX_Blocking.c -mavx -mavx2 -mfma -msse -msse2 -msse3 -o blocking
cd ..
cd GPU-part
nvcc MatMul_gpu.cu -o baseline
nvcc MatMul_gpu_blocking.cu -o blocking