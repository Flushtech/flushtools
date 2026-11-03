/*
 * ABI test: compiles against include/flushtools.h and links the built shared
 * library, proving the header, struct layouts and symbols all agree.
 * Plain C99, builds with gcc, clang and MSVC.
 */
#include "flushtools.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

/* Struct layouts must match the Odin side (64-bit targets). */
#define LAYOUT_CHECK(name, cond) typedef char layout_check_##name[(cond) ? 1 : -1]
LAYOUT_CHECK(arena, sizeof(fl_arena) == 24);
LAYOUT_CHECK(array, sizeof(fl_array) == 32);
LAYOUT_CHECK(string, sizeof(fl_string) == 24);
LAYOUT_CHECK(timer, sizeof(fl_timer) == 16);
LAYOUT_CHECK(writer, sizeof(fl_bit_writer) == 24);
LAYOUT_CHECK(reader, sizeof(fl_bit_reader) == 24);
LAYOUT_CHECK(rng, sizeof(fl_rng) == 8);

static int failures = 0;
#define CHECK(cond)                                                            \
  do {                                                                         \
    if (!(cond)) {                                                             \
      printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);                   \
      failures++;                                                              \
    }                                                                          \
  } while (0)

static void on_tick(void *user_data) { (*(int *)user_data)++; }

int main(void) {
  /* version */
  CHECK(strcmp(fl_version(), FLUSHTOOLS_VERSION) == 0);

  /* arena */
  {
    uint64_t storage[8]; /* 64 bytes, 8-byte aligned */
    fl_arena a;
    fl_arena_init(&a, (uint8_t *)storage, sizeof(storage));
    void *p1 = fl_arena_alloc(&a, 10);
    void *p2 = fl_arena_alloc(&a, 8);
    CHECK(p1 == (void *)storage);
    CHECK(p2 != NULL && ((uintptr_t)p2 % 8) == 0);
    CHECK(a.offset == 24);
    CHECK(fl_arena_alloc(&a, 41) == NULL);
    CHECK(fl_arena_alloc(&a, 40) != NULL);
    CHECK(fl_arena_remaining(&a) == 0);
    CHECK(fl_arena_alloc(&a, 1) == NULL);
    fl_arena_reset(&a);
    CHECK(fl_arena_remaining(&a) == 64);
    void *p3 = fl_arena_alloc_aligned(&a, 4, 32);
    CHECK(p3 != NULL && ((uintptr_t)p3 % 32) == 0);
    CHECK(fl_arena_alloc_aligned(&a, 4, 3) == NULL); /* not a power of two */
  }

  /* fixed-capacity array */
  {
    int storage[4] = {0};
    fl_array a;
    int first = 10, middle = 20, last = 30;
    CHECK(fl_array_init(&a, (uint8_t *)storage, 4, sizeof(int)));
    CHECK(!fl_array_init(&a, NULL, 4, sizeof(int)));
    CHECK(!fl_array_init(&a, (uint8_t *)storage, 4, 0));
    CHECK(fl_array_push(&a, &first));
    CHECK(fl_array_push(&a, &last));
    CHECK(fl_array_insert(&a, 1, &middle));
    CHECK(a.count == 3);
    CHECK(*(int *)fl_array_at(&a, 0) == 10);
    CHECK(*(int *)fl_array_at(&a, 1) == 20);
    CHECK(*(int *)fl_array_at(&a, 2) == 30);
    CHECK(fl_array_at(&a, 3) == NULL);
    CHECK(fl_array_remove(&a, 1));
    CHECK(*(int *)fl_array_at(&a, 1) == 30);
    CHECK(!fl_array_remove(&a, 2));
    CHECK(fl_array_push(&a, &middle));
    CHECK(fl_array_push(&a, &first));
    CHECK(!fl_array_push(&a, &first));
    fl_array_clear(&a);
    CHECK(a.count == 0 && fl_array_at(&a, 0) == NULL);
    CHECK(fl_array_init(&a, NULL, 0, sizeof(int)));
  }

  /* fixed-capacity string */
  {
    char storage[12];
    fl_string s;
    CHECK(fl_string_init(&s, storage, sizeof(storage)));
    CHECK(storage[0] == '\0' && s.length == 0);
    CHECK(fl_string_append(&s, "hello"));
    CHECK(fl_string_append(&s, " world"));
    CHECK(strcmp(storage, "hello world") == 0 && s.length == 11);
    CHECK(!fl_string_append(&s, "!"));
    CHECK(strcmp(storage, "hello world") == 0 && s.length == 11);
    CHECK(!fl_string_append(&s, NULL));
    fl_string_clear(&s);
    CHECK(storage[0] == '\0' && s.length == 0);
    CHECK(!fl_string_init(NULL, storage, sizeof(storage)));
    CHECK(!fl_string_init(&s, NULL, sizeof(storage)));
    CHECK(!fl_string_init(&s, storage, 0));
  }

  /* bit packing, including the README example */
  {
    uint8_t buf[16];
    fl_bit_writer w;
    CHECK(fl_bit_writer_init(&w, buf, sizeof(buf)));
    CHECK(fl_bit_writer_write(&w, 5u, 3));
    CHECK(buf[0] == 5);
    CHECK(fl_bit_writer_write(&w, 0x1ABCDu, 17));
    CHECK(fl_bit_writer_write(&w, 0xDEADBEEFu, 32));
    CHECK(fl_bit_writer_bytes_used(&w) == 7); /* 52 bits */

    fl_bit_reader r;
    CHECK(fl_bit_reader_init(&r, buf, sizeof(buf)));
    CHECK(fl_bit_reader_read(&r, 3) == 5u);
    CHECK(fl_bit_reader_read(&r, 17) == 0x1ABCDu);
    CHECK(fl_bit_reader_read(&r, 32) == 0xDEADBEEFu);
    CHECK(fl_bit_reader_remaining(&r) == 128 - 52);

    /* overflow is all-or-nothing */
    uint8_t one[1];
    fl_bit_writer small;
    CHECK(fl_bit_writer_init(&small, one, 1));
    CHECK(fl_bit_writer_write(&small, 0xFFu, 8));
    CHECK(!fl_bit_writer_write(&small, 1u, 1));
    CHECK(!fl_bit_writer_write(&small, 1u, 33));
    CHECK(!fl_bit_writer_init(NULL, one, 1));
  }

  /* quantization */
  {
    uint32_t q = fl_net_quantize(0.75f, 0.0f, 1.0f, 8);
    CHECK(q == 191);
    CHECK(fabsf(fl_net_dequantize(q, 0.0f, 1.0f, 8) - 0.75f) < 1.0f / 255.0f);
    CHECK(fl_net_quantize(-5.0f, 0.0f, 1.0f, 8) == 0);   /* clamps low */
    CHECK(fl_net_quantize(5.0f, 0.0f, 1.0f, 8) == 255);  /* clamps high */
    CHECK(fl_net_quantize(1.0f, 0.0f, 1.0f, 32) == 0xFFFFFFFFu);
    CHECK(fl_net_quantize(0.5f, 0.0f, 1.0f, 0) == 0);    /* invalid bits */

    uint16_t packed = fl_compress_coord(123.4f, 0.0f, 1000.0f);
    CHECK(fabsf(fl_decompress_coord(packed, 0.0f, 1000.0f) - 123.4f) < 0.02f);
    CHECK(fl_compress_coord(0.0f, 0.0f, 1000.0f) == 0);
    CHECK(fl_compress_coord(1000.0f, 0.0f, 1000.0f) == 65535);
  }

  /* timer */
  {
    fl_timer t;
    CHECK(!fl_timer_init(&t, -1));
    CHECK(fl_timer_init(&t, 0));
    CHECK(fl_timer_is_finished(&t));
    CHECK(fl_timer_init(&t, 100));
    CHECK(!fl_timer_is_finished(&t));
    CHECK(fl_timer_get_elapsed(&t) < 1.0);

    int ticks = 0;
    CHECK(fl_timer_init(&t, 2));
    CHECK(fl_timer_run(&t, on_tick, &ticks));
    CHECK(fl_timer_is_finished(&t));
    CHECK(ticks >= 1 && ticks <= 2);
    CHECK(!fl_timer_run(&t, NULL, NULL));
  }

  /* random */
  {
    fl_rng a, b;
    fl_rng_seed(&a, 42);
    fl_rng_seed(&b, 42);
    for (int i = 0; i < 100; i++) {
      CHECK(fl_rng_next(&a) == fl_rng_next(&b));
    }
    for (int i = 0; i < 10000; i++) {
      uint64_t roll = fl_rng_range(&a, 1, 6);
      CHECK(roll >= 1 && roll <= 6);
    }
    CHECK(fl_rng_range(&a, 5, 5) == 5);
    CHECK(fl_rng_range(&a, 9, 3) == 0);
    (void)fl_rng_range(&a, 0, UINT64_MAX); /* full span must not hang */

    int seen[6] = {0};
    for (int i = 0; i < 1000; i++) {
      uint64_t v = fl_random_gen(1, 6);
      CHECK(v >= 1 && v <= 6);
      if (v >= 1 && v <= 6) seen[v - 1]++;
    }
    for (int i = 0; i < 6; i++) CHECK(seen[i] > 0);

    fl_random_seed(7);
    uint64_t first = fl_random_gen(0, 1000000);
    fl_random_seed(7);
    CHECK(fl_random_gen(0, 1000000) == first);
  }

  if (failures == 0) {
    printf("OK: C ABI test passed (flushtools %s)\n", fl_version());
    return 0;
  }
  printf("%d check(s) failed\n", failures);
  return 1;
}
