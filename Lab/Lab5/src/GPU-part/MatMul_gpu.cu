#include <cuda_profiler_api.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

int N = (1 << 8);
#define BLOCK_SIZE 16  // a matrix block size default 16×16
float bound = 100.0;
const float accuracy = 0.5;

__global__ void gemm_baseline(float *A, float *B, float *C, int N) {
    // one thread calcultate one element of C
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;

    if (i >= N || j >= N) {
        return;
    }

    // suppose C[i][j] initializes with 0
    float tempc = 0.0f;  // use a local var to avoid many global memory access
    for (int k = 0; k < N; k++) {
        // C[i * N + j] += A[i * N + k] * B[k * N + j];
        tempc += A[i * N + k] * B[k * N + j];
    }
    C[i * N + j] = tempc;
}

void gemm_baseline_cpu(float *A, float *B, float *C) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            for (int k = 0; k < N; k++) {
                C[i * N + j] += A[i * N + k] * B[k * N + j];  // C[i][j] += A[i][k] * B[k][j];
            }
        }
    }
}

void gemm_verify(float *A, float *B, float *C) {
    /**
     * @brief verify avx correctness with baseline method
     * @param C has been calculated with avx-block method
     * now use baseline method calculate again and compare
     */
    float *C_baseline = (float *)malloc(N * N * sizeof(float));
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            C_baseline[i * N + j] = 0.0;
        }
    }
    gemm_baseline_cpu(A, B, C_baseline);

    FILE *f = fopen("../../output/GPU-part/C_gpu_verify.txt", "w");
    if (f == NULL) {
        printf("cannot open output file\n");
    }
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            fprintf(f, "%-20f ", C_baseline[i * N + j]);
        }
        fprintf(f, "\n");
    }
    fclose(f);

    // compare C and C_baseline
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            if (fabs(C[i * N + j] - C_baseline[i * N + j]) > accuracy) {
                printf("Wrong calculation in gpu-case!\n");
                return;
            }
        }
    }

    printf("GPU-case correctness verified.\n");
    free(C_baseline);
}

int main(int argc, char *argv[]) {
    if (argc == 2) {
        // with matrix size argument
        N = atoi(argv[1]);
    } else if (argc == 3) {
        // with matrix size and bound
        N = atoi(argv[1]);
        bound = atof(argv[2]);
    }

    // CPU malloc and initialization
    float *A = (float *)malloc(N * N * sizeof(float));
    float *B = (float *)malloc(N * N * sizeof(float));
    float *C = (float *)malloc(N * N * sizeof(float));
    // initialize A and B
    srand((unsigned int)time(NULL));
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            double a = (-bound) + (1.0 * rand() / (1.0 * RAND_MAX)) * (2 * bound);
            double b = (-bound) + (1.0 * rand() / (1.0 * RAND_MAX)) * (2 * bound);
            A[i * N + j] = a;
            B[i * N + j] = b;
            C[i * N + j] = 0.0;
        }
    }

    // GPU malloc and initialization
    float *Ag, *Bg, *Cg;
    cudaMalloc((void **)&Ag, sizeof(float) * N * N);
    cudaMalloc((void **)&Bg, sizeof(float) * N * N);
    cudaMalloc((void **)&Cg, sizeof(float) * N * N);
    // set gpu data using cpu initialization values
    cudaMemcpy(Ag, A, sizeof(float) * N * N, cudaMemcpyHostToDevice);
    cudaMemcpy(Bg, B, sizeof(float) * N * N, cudaMemcpyHostToDevice);
    cudaMemcpy(Cg, C, sizeof(float) * N * N, cudaMemcpyHostToDevice);

    // define grid size and block size
    int bN = BLOCK_SIZE;  // a thread block is bN×bN
    dim3 thread_per_block(bN, bN);
    dim3 block_per_grid(N / bN, N / bN);

    cudaEvent_t start, end;
    float running_time;
    cudaEventCreate(&start);
    cudaEventCreate(&end);
    cudaEventRecord(start, 0);

    gemm_baseline<<<block_per_grid, thread_per_block>>>(Ag, Bg, Cg, N);

    cudaEventRecord(end, 0);
    cudaEventSynchronize(end);
    cudaEventElapsedTime(&running_time, start, end);
    cudaEventDestroy(start);
    cudaEventDestroy(end);
    printf("gpu-case running time: %lf ms\n", running_time);

    // copy the result from gpu to cpu
    cudaMemcpy(C, Cg, sizeof(float) * N * N, cudaMemcpyDeviceToHost);

    gemm_verify(A, B, C);

    FILE *f = fopen("../../output/GPU-part/C_gpu.txt", "w");
    if (f == NULL) {
        printf("cannot open output file\n");
        return 0;
    }
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            fprintf(f, "%-20f ", C[i * N + j]);
        }
        fprintf(f, "\n");
    }
    fclose(f);

    // free memory
    free(A);
    free(B);
    free(C);
    cudaFree(Ag);
    cudaFree(Bg);
    cudaFree(Cg);
    cudaDeviceSynchronize();
    cudaProfilerStop();
    return 0;
}