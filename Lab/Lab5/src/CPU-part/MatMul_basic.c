#include <stdlib.h>
#include <time.h>
#include <stdio.h>

int N = (1 << 8);  // matrix size
float bound = 50.0; // element ∈ [-100.0, 100.0]

void gemm_baseline(float *A, float *B, float *C) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            for (int k = 0; k < N; k++) {
                C[i * N + j] += A[i * N + k] * B[k * N + j]; // C[i][j] += A[i][k] * B[k][j];
            }
        }
    }
}

int main(int argc, char* argv[]) {

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

    gemm_baseline(A, B, C);

    end = clock();
    printf("baseline running clocks: %ld\n", end-start);

    FILE *f = fopen("../../output/CPU-part/C_basic.txt", "w");
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


    free(A);
    free(B);
    free(C);
    fclose(f);
    return 0;
}