/*
 * Multithreaded test (POSIX threads; skipped on Windows). Run under
 * ThreadSanitizer in CI to catch data races in the per-thread RNG and timer.
 */
#include "flushtools.h"

#include <pthread.h>
#include <stdio.h>

#define THREADS 8
#define ROLLS 100000

static uint64_t sums[THREADS];

static void *worker(void *arg) {
  long id = (long)arg;
  uint64_t sum = 0;
  for (int i = 0; i < ROLLS; i++) {
    uint64_t v = fl_random_gen(1, 6);
    if (v < 1 || v > 6) {
      sums[id] = UINT64_MAX;
      return NULL;
    }
    sum += v;
  }
  fl_timer t;
  if (!fl_timer_init(&t, 0) || !fl_timer_is_finished(&t)) {
    sums[id] = UINT64_MAX;
    return NULL;
  }
  sums[id] = sum;
  return NULL;
}

int main(void) {
  pthread_t threads[THREADS];
  for (long i = 0; i < THREADS; i++) {
    if (pthread_create(&threads[i], NULL, worker, (void *)i) != 0) {
      return 2;
    }
  }
  for (int i = 0; i < THREADS; i++) {
    pthread_join(threads[i], NULL);
  }

  int bad = 0;
  for (int i = 0; i < THREADS; i++) {
    /* mean of a d6 is 3.5, so the sum should be near 350000 */
    if (sums[i] < 340000 || sums[i] > 360000) {
      printf("thread %d: unexpected sum %llu\n", i, (unsigned long long)sums[i]);
      bad = 1;
    }
  }
  puts(bad ? "FAIL: thread test" : "OK: thread test passed");
  return bad;
}
