#include <stdio.h>
#include <sys/time.h>

double cpuTimer() {
  struct timeval clock;
  gettimeofday(&clock, NULL);
  
  return ((double) clock.tv_sec + (double) clock.tv_usec * 1.e-6);
}

void initWith(float num, float *a, int N)
{
  for(int i = 0; i < N; ++i)
  {
    a[i] = num;
  }
}

__global__
void addVectorsInto(float *result, float *a, float *b, int N)
{
  int index = threadIdx.x + blockIdx.x * blockDim.x;
  int stride = blockDim.x * gridDim.x;

  for(int i = index; i < N; i += stride)
  {
    result[i] = a[i] + b[i];
  }
}

void checkElementsAre(float target, float *vector, int N)
{
  for(int i = 0; i < N; i++)
  {
    if(vector[i] != target)
    {
      printf("FAIL: vector[%d] - %0.0f does not equal %0.0f\n", i, vector[i], target);
      exit(1);
    }
  }
  printf("Success! All values calculated correctly.\n");
}

int main()
{
  int deviceId;
  int numberOfSMs;

  cudaGetDevice(&deviceId);
  cudaDeviceGetAttribute(&numberOfSMs, cudaDevAttrMultiProcessorCount, deviceId);

  const int N = 2<<29;
  size_t size = N * sizeof(float);

  float *a;
  float *b;
  float *c;
  float *d;
  float *e;
  float *f;
  float *g;

  cudaMallocManaged(&a, size);
  cudaMallocManaged(&b, size);
  cudaMallocManaged(&c, size);
  cudaMallocManaged(&d, size);
  cudaMallocManaged(&e, size);
  cudaMallocManaged(&f, size);
  cudaMallocManaged(&g, size);

  initWith(3, a, N);
  initWith(4, b, N);
  initWith(0, c, N);
  initWith(0, d, N);
  initWith(5, e, N);
  initWith(0, f, N);
  initWith(6, g, N);

  size_t threadsPerBlock;
  size_t numberOfBlocks;

  threadsPerBlock = 256;
  numberOfBlocks = 32 * numberOfSMs;

  cudaError_t addVectorsErr;
  cudaError_t asyncErr;

  double start = cpuTimer(), end;
  addVectorsInto<<<numberOfBlocks, threadsPerBlock>>>(c, a, b, N);

  addVectorsErr = cudaGetLastError();
  if(addVectorsErr != cudaSuccess) printf("Error: %s\n", cudaGetErrorString(addVectorsErr));

  asyncErr = cudaDeviceSynchronize();
  if(asyncErr != cudaSuccess) printf("Error: %s\n", cudaGetErrorString(asyncErr));
  
  addVectorsInto<<<numberOfBlocks, threadsPerBlock>>>(d, c, e, N);

  addVectorsErr = cudaGetLastError();
  if (addVectorsErr != cudaSuccess) printf("Error: %s\n", cudaGetErrorString(addVectorsErr));

  asyncErr = cudaDeviceSynchronize();
  if (asyncErr != cudaSuccess) printf("Error: %s\n", cudaGetErrorString(asyncErr));

  addVectorsInto<<<numberOfBlocks, threadsPerBlock>>>(f, d, g, N);
  
  addVectorsErr = cudaGetLastError();
  if (addVectorsErr != cudaSuccess) printf("Error: %s\n", cudaGetErrorString(addVectorsErr));

  asyncErr = cudaDeviceSynchronize();
  if (asyncErr != cudaSuccess) printf("Error: %s\n", cudaGetErrorString(asyncErr));

  end = cpuTimer();

  double rtime = end - start;
  printf("Kernels executed in %lf seconds.\n", rtime);

  checkElementsAre((3 + 4 + 5 + 6), f, N);

  cudaFree(a);
  cudaFree(b);
  cudaFree(c);
}

