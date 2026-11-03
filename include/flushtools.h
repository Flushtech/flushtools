/*
 * FlushTools - small systems utilities with a stable C ABI.
 *
 * Implemented in Odin, shipped as a shared library (flushtools.dll,
 * libflushtools.so, libflushtools.dylib). Link against it and include this
 * header; there is nothing else to configure.
 *
 * Validated release targets: Linux x86_64 and Windows x86_64. Other targets
 * are not currently validated.
 * MIT License - Copyright (c) 2026 Austin Clark
 */
#ifndef FLUSHTOOLS_H
#define FLUSHTOOLS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Updated automatically by release-please. */
#define FLUSHTOOLS_VERSION "0.0.0" /* x-release-please-version */

/* Library version string; matches FLUSHTOOLS_VERSION if header and binary agree. */
const char *fl_version(void);

/* ---------------------------------------------------------------------------
 * Arena: bump allocator over a caller-owned buffer.
 * ------------------------------------------------------------------------- */

typedef struct fl_arena {
  uint8_t *buffer;
  size_t capacity;
  size_t offset;
} fl_arena;

void fl_arena_init(fl_arena *arena, uint8_t *buffer, size_t capacity);
/* 8-byte aligned. Returns NULL when out of space. Memory is not zeroed. */
void *fl_arena_alloc(fl_arena *arena, size_t size);
/* `alignment` must be a non-zero power of two. */
void *fl_arena_alloc_aligned(fl_arena *arena, size_t size, size_t alignment);
void fl_arena_reset(fl_arena *arena);
/* Save the current offset; pass it to fl_arena_rewind for temporary allocations. */
size_t fl_arena_mark(const fl_arena *arena);
/* Rewind to an earlier mark. Returns false for a mark beyond the current offset. */
bool fl_arena_rewind(fl_arena *arena, size_t mark);
size_t fl_arena_remaining(const fl_arena *arena);

/* ---------------------------------------------------------------------------
 * Fixed-capacity array: contiguous caller-owned storage, no allocations.
 * The backing buffer must be aligned for the element type. Elements passed to
 * push/insert must not alias the backing buffer.
 * ------------------------------------------------------------------------- */

typedef struct fl_array {
  uint8_t *data;
  size_t count;
  size_t capacity;
  size_t element_size;
} fl_array;

/* A zero-capacity array may use a NULL data pointer. */
bool fl_array_init(fl_array *array, uint8_t *data, size_t capacity,
                   size_t element_size);
/* Copy one element into the next slot. False if full or arguments are invalid. */
bool fl_array_push(fl_array *array, const void *element);
/* Insert before index; index == count appends. Preserves element order. */
bool fl_array_insert(fl_array *array, size_t index, const void *element);
/* Remove at index and shift later elements left. */
bool fl_array_remove(fl_array *array, size_t index);
/* Pointer to element at index, or NULL when out of bounds. */
void *fl_array_at(fl_array *array, size_t index);
/* Set count to zero; does not clear the backing memory. */
void fl_array_clear(fl_array *array);

/* ---------------------------------------------------------------------------
 * Fixed-capacity string: caller-owned, null-terminated buffer.
 * Capacity includes the trailing NUL byte.
 * ------------------------------------------------------------------------- */

typedef struct fl_string {
  char *data;
  size_t length;
  size_t capacity;
} fl_string;

bool fl_string_init(fl_string *string, char *buffer, size_t capacity);
/* Appends a null-terminated string. False on invalid input or insufficient space. */
bool fl_string_append(fl_string *string, const char *value);
/* Clears the string but leaves the buffer allocated to the caller. */
void fl_string_clear(fl_string *string);

/* ---------------------------------------------------------------------------
 * Bit packing (LSB-first). Counts are 0..32 bits per call.
 * ------------------------------------------------------------------------- */

typedef struct fl_bit_writer {
  uint8_t *buffer;
  uint64_t current_bit;
  uint64_t bit_capacity;
} fl_bit_writer;

typedef struct fl_bit_reader {
  const uint8_t *buffer;
  uint64_t current_bit;
  uint64_t bit_capacity;
} fl_bit_reader;

/* Zeroes the buffer. Returns false on NULL arguments. */
bool fl_bit_writer_init(fl_bit_writer *writer, uint8_t *buffer,
                        size_t byte_capacity);
/* All-or-nothing: returns false (and writes nothing) if the bits do not fit. */
bool fl_bit_writer_write(fl_bit_writer *writer, uint32_t value, int count);
/* Bytes to send after writing. */
size_t fl_bit_writer_bytes_used(const fl_bit_writer *writer);

bool fl_bit_reader_init(fl_bit_reader *reader, const uint8_t *buffer,
                        size_t byte_length);
uint64_t fl_bit_reader_remaining(const fl_bit_reader *reader);
/* Returns 0 without advancing if fewer than `count` bits remain. */
uint32_t fl_bit_reader_read(fl_bit_reader *reader, int count);

/* ---------------------------------------------------------------------------
 * Quantization and coordinate compression.
 * `bits` must be 1..32 and max > min; invalid input returns 0 (quantize) or
 * `min` (dequantize).
 * ------------------------------------------------------------------------- */

uint32_t fl_net_quantize(float value, float min, float max, int bits);
float fl_net_dequantize(uint32_t value, float min, float max, int bits);

uint16_t fl_compress_coord(float value, float min, float max);
float fl_decompress_coord(uint16_t value, float min, float max);

/* ---------------------------------------------------------------------------
 * Timer: monotonic, fractional-second resolution. Treat the struct as opaque.
 * ------------------------------------------------------------------------- */

typedef struct fl_timer {
  int64_t start_ns;
  int32_t duration;
  int32_t reserved_;
} fl_timer;

typedef void (*fl_tick_callback)(void *user_data);

/* Return false on NULL timer or negative duration. */
bool fl_timer_init(fl_timer *timer, int duration_seconds);
bool fl_timer_reset(fl_timer *timer, int new_duration_seconds);
double fl_timer_get_elapsed(const fl_timer *timer);
bool fl_timer_is_finished(const fl_timer *timer);
/* Blocks until finished; calls callback after each elapsed whole second.
 * A zero-duration timer completes without invoking the callback. */
bool fl_timer_run(fl_timer *timer, fl_tick_callback callback, void *user_data);

/* ---------------------------------------------------------------------------
 * Random: NON-CRYPTOGRAPHIC (SplitMix64). Never use for secrets.
 * ------------------------------------------------------------------------- */

typedef struct fl_rng {
  uint64_t state;
} fl_rng;

void fl_rng_seed(fl_rng *rng, uint64_t seed);
uint64_t fl_rng_next(fl_rng *rng);
/* Inclusive, unbiased. Returns 0 if max < min. */
uint64_t fl_rng_range(fl_rng *rng, uint64_t min, uint64_t max);

/* Per-thread generator, auto-seeded from the monotonic clock. */
void fl_random_seed(uint64_t seed);
uint64_t fl_random_gen(uint64_t min, uint64_t max);

#ifdef __cplusplus
}
#endif

#endif /* FLUSHTOOLS_H */
