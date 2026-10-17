/*
 * Sanitizer self-test: each mode commits ONE deliberate bug. CI runs these
 * and requires the sanitizer to FAIL, proving the tooling really detects
 * problems (a green sanitizer run means nothing if it can't go red).
 *   overflow : tells the library a 4-byte heap block is 64 bytes
 *   leak     : leaks a malloc'd block
 */
#include "flushtools.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
  if (argc < 2) {
    return 2;
  }
  if (strcmp(argv[1], "overflow") == 0) {
    uint8_t *small = (uint8_t *)malloc(4);
    fl_bit_writer w;
    fl_bit_writer_init(&w, small, 64); /* library zeroes 64 bytes: overflow */
    free(small);
    return 0;
  }
  if (strcmp(argv[1], "leak") == 0) {
    /* volatile stores stop the optimiser from deleting the allocation */
    void *volatile leaked = malloc(128);
    leaked = NULL;
    return 0;
  }
  return 2;
}
