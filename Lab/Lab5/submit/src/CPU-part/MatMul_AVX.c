#include <immintrin.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int N = (1 << 8);     // matrix size
float bound = 50.0;  // element ∈ [-50.0, 50.0]
const float accuracy = 0.5;

void gemm_baseline(float *A, float *B, float *C) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            for (int k = 0; k < N; k++) {
                C[i * N + j] += A[i * N + k] * B[k * N + j];  // C[i][j] += A[i][k] * B[k][j];
            }
        }
    }
}

void gemm_avx(float *A, float *B, float *C) {
    for (int i = 0; i < N; i++) {
        for (int k = 0; k < N; k++) {
            float tmpa = A[i * N + k];
            __m256 a8 = _mm256_set1_ps(tmpa);  // a8 is a vector with 8 floats with value A[i][k]
            for (int j = 0; j <= N - 8; j += 8) {
                __m256 b8 = _mm256_loadu_ps(B + k * N + j);  // 8 floats starting from B[k][j]
                __m256 c8 = _mm256_loadu_ps(C + i * N + j);  // 8 floats starting from C[i][j]
                c8 = _mm256_fmadd_ps(a8, b8, c8);            // C[i][j] += A[i][k] + B[k][j]
                _mm256_storeu_ps(C + i * N + j, c8);
            }
        }
    }
}

void gemm_verify(float *A, float *B, float *C) {
    /**
     * @brief verify avx correctness with baseline method
     * @param C has been calculated with avx method
     * now use baseline method calculate again and compare
     */
    float *C_baseline = (float *)malloc(N * N * sizeof(float));
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            C_baseline[i * N + j] = 0.0;
        }
    }
    clock_t start, end;
    start = clock();
    gemm_baseline(A, B, C_baseline);
    end = clock();
    printf("baseline running clocks: %ld\n", end-start);

    FILE *f = fopen("../../output/CPU-part/C_avx_verify.txt", "w");
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
                printf("Wrong calculation in AVX!\n");
                return;
            }
        }
    }

    printf("AVX correctness verified.\n");
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

    float *A = (float *)malloc(N * N * sizeof(float));
    float *B = (float *)malloc(N * N * sizeof(float));
    float *C = (float *)malloc(N * N * sizeof(float));

    srand((unsigned int)time(NULL));
    // initialize A and B
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            double a = (-bound) + (1.0 * rand() / (1.0 * RAND_MAX)) * (2 * bound);
            double b = (-bound) + (1.0 * rand() / (1.0 * RAND_MAX)) * (2 * bound);
            A[i * N + j] = a;
            B[i * N + j] = b;
            C[i * N + j] = 0.0;
        }
    }


    

    clock_t start, end;
    start = clock();

    gemm_avx(A, B, C);

    end = clock();
    printf("avx running clocks: %ld\n", end - start);
    printf("avx running time/ms: %ld\n", 1000000 * (end - start) / (CLOCKS_PER_SEC));






    FILE *f = fopen("../../output/CPU-part/C_avx.txt", "w");
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

    gemm_verify(A, B, C);


    free(A);
    free(B);
    free(C);
    fclose(f);
    return 0;
}