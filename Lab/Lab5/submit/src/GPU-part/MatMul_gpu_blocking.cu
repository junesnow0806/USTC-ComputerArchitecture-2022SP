#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <cuda_profiler_api.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>


// 本机上每个线程块的共享内存大小为48KB
// 一个float为4B
// 共享内存最多可容纳12K个float
// 有三个矩阵, 假设留空一个矩阵的空间, 平均每个矩阵最多可用3KB
// 32×32 = 1024
// 线程块大小与矩阵块大小保持一致


int N = (1 << 8);
#define BLOCK_SIZE 8 // a matrix block size default 16×16
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
    float tempc = 0.0f; // use a local var to avoid many global memory access
    for (int k = 0; k < N; k++) {
        // C[i * N + j] += A[i * N + k] * B[k * N + j];
        tempc += A[i * N + k] * B[k * N + j];
    }
    C[i * N + j] = tempc;
}

__global__ void gemm_blocking(float *A, float *B, float *C, int N) {
    // one thread calculate one element of C, i.e c[i][j]

    // malloc shared memory
    __shared__ float sharedA[BLOCK_SIZE][BLOCK_SIZE];
    __shared__ float sharedB[BLOCK_SIZE][BLOCK_SIZE];

    int tx = threadIdx.x, ty = threadIdx.y; // thread index in the block
    int i = blockIdx.x * blockDim.x + threadIdx.x; // element index of C
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    // bi, bj, bk denotes block i, j, k
    // now calculating block C[bi][bj]
    int bi = blockIdx.x;
    int bj = blockIdx.y;


    if (i >= N || j >= N) {
        return;
    }

    float sum = 0.0; // c[i][j]
    for (int bk = 0; bk < N / BLOCK_SIZE; bk++) {
        // block C[bi][bj] = summation_bk{ A[bi][bk] * B[bk][bj] }
        // there are N/BLOCK_SIZE blocks in a row/column
        // bk denotes it is the bk-th block in the row of A anf the column of B
        
        // load the block A[bi][bk] and B[bk][bj]
        int Ai = bi * BLOCK_SIZE + tx; // element index of A
        int Aj = bk * BLOCK_SIZE + ty;
        int Bi = bk * BLOCK_SIZE + tx; // element index of B
        int Bj = bj * BLOCK_SIZE + ty;
        sharedA[tx][ty] = A[Ai * N + Aj];
        sharedB[tx][ty] = B[Bi * N + Bj];
        __syncthreads(); // wait until the whole block A[bi][bk], B[bk][bj] loaded to the shared memory
        for (int tk = 0; tk < BLOCK_SIZE; tk++) {
            sum += sharedA[tx][tk] * sharedB[tk][ty];
        }
        __syncthreads(); // wait until all threads finished then next bk
    }

    C[i * N + j] = sum;
}

void gemm_baseline_cpu(float *A, float *B, float *C) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            for (int k = 0; k < N; k++) {
                C[i * N + j] += A[i * N + k] * B[k * N + j]; // C[i][j] += A[i][k] * B[k][j];
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

    FILE *f = fopen("../../output/GPU-part/C_gpu_blocking_verify.txt", "w");
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
                printf("Wrong calculation in gpu-blocking-case!\n");
                return;
            }
        }
    }

    printf("GPU-blocking-case correctness verified.\n");
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
    cudaMalloc((void**)&Ag, sizeof(float) * N * N);
    cudaMalloc((void**)&Bg, sizeof(float) * N * N);
    cudaMalloc((void**)&Cg, sizeof(float) * N * N);
    // set gpu data using cpu initialization values
    cudaMemcpy(Ag, A, sizeof(float) * N * N, cudaMemcpyHostToDevice);
    cudaMemcpy(Bg, B, sizeof(float) * N * N, cudaMemcpyHostToDevice);
    cudaMemcpy(Cg, C, sizeof(float) * N * N, cudaMemcpyHostToDevice);


    // define grid size and block size
    int bN = BLOCK_SIZE; // a thread block is bN×bN
    dim3 thread_per_block(bN, bN);
    dim3 block_per_grid(N/bN, N/bN);

    cudaEvent_t start, end;
    float running_time;
    cudaEventCreate(&start);
    cudaEventCreate(&end);
    cudaEventRecord(start, 0);

    gemm_blocking<<<block_per_grid, thread_per_block>>>(Ag, Bg, Cg, N);

    cudaEventRecord(end, 0);
    cudaEventSynchronize(end);
    cudaEventElapsedTime(&running_time, start, end);
    cudaEventDestroy(start);
    cudaEventDestroy(end);
    printf("gpu-blocking-case running time: %lf ms\n", running_time);

    // copy the result from gpu to cpu
    cudaMemcpy(C, Cg, sizeof(float) * N * N, cudaMemcpyDeviceToHost);

    gemm_verify(A, B, C);




    // to compare baseline and blocking
    cudaEvent_t start1, end1;
    float running_time1;
    cudaEventCreate(&start1);
    cudaEventCreate(&end1);
    cudaEventRecord(start1, 0);

    gemm_baseline<<<block_per_grid, thread_per_block>>>(Ag, Bg, Cg, N);

    cudaEventRecord(end1, 0);
    cudaEventSynchronize(end1);
    cudaEventElapsedTime(&running_time1, start1, end1);
    cudaEventDestroy(start1);
    cudaEventDestroy(end1);
    printf("gpu-baseline running time: %lf ms\n", running_time1);



    FILE *f = fopen("../../output/GPU-part/C_gpu_blocking.txt", "w");
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