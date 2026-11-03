#include "flushtools.h"

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>

static int fail(const char *message) {
    fprintf(stderr, "FlushTools example: %s\n", message);
    return EXIT_FAILURE;
}

int main(void) {
    printf("FlushTools %s\n", fl_version());

    /* 1. Arena: allocate from memory owned by the application. */
    uint64_t arena_storage[32];
    fl_arena arena;
    fl_arena_init(&arena, (uint8_t *)arena_storage, sizeof arena_storage);

    int *scores = (int *)fl_arena_alloc(&arena, 3 * sizeof *scores);
    if (scores == NULL) {
        return fail("arena allocation failed");
    }

    scores[0] = 120;
    scores[1] = 95;
    scores[2] = 108;
    printf("arena scores: %d, %d, %d (%zu bytes remain)\n",
           scores[0], scores[1], scores[2], fl_arena_remaining(&arena));

    /* 2. Bit packing: write a 3-bit value and read it back. */
    uint8_t packet[4];
    fl_bit_writer writer;
    if (!fl_bit_writer_init(&writer, packet, sizeof packet) ||
        !fl_bit_writer_write(&writer, 5, 3)) {
        return fail("could not write packet bits");
    }

    fl_bit_reader reader;
    if (!fl_bit_reader_init(&reader, packet, fl_bit_writer_bytes_used(&writer))) {
        return fail("could not initialize packet reader");
    }

    uint32_t decoded = fl_bit_reader_read(&reader, 3);
    printf("packed value: 5 -> %" PRIu32 "\n", decoded);

    /* 3. Quantization: represent a normalized float with 8 bits. */
    const float original = 0.75f;
    uint32_t packed = fl_net_quantize(original, 0.0f, 1.0f, 8);
    float restored = fl_net_dequantize(packed, 0.0f, 1.0f, 8);
    printf("quantized %.2f -> %" PRIu32 " -> %.4f\n",
           (double)original, packed, (double)restored);

    /* 4. Random: explicit state gives reproducible sequences. */
    fl_rng rng;
    fl_rng_seed(&rng, 0xC0FFEEu);
    printf("random roll: %" PRIu64 "\n", fl_rng_range(&rng, 1, 6));

    /* 5. Timer: monotonic elapsed time, measured in fractional seconds. */
    fl_timer timer;
    if (!fl_timer_init(&timer, 10)) {
        return fail("could not initialize timer");
    }
    printf("timer elapsed: %.6f seconds\n", fl_timer_get_elapsed(&timer));

    /* Reset the arena when this batch of temporary allocations is finished. */
    fl_arena_reset(&arena);
    printf("arena reset: %zu bytes remain\n", fl_arena_remaining(&arena));

    return EXIT_SUCCESS;
}
