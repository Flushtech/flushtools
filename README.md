# FlushTools

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Language: Odin](https://img.shields.io/badge/written%20in-Odin-1f6feb.svg)
![Platforms](https://img.shields.io/badge/platforms-linux%20%7C%20macos%20%7C%20windows-lightgrey.svg)

Small systems utilities written in [Odin](https://odin-lang.org) and shipped as a
shared library with a plain **C ABI**: an arena allocator, bit packing, float
quantization, a monotonic timer, and a fast non-cryptographic RNG.

Use it from C, C++, Rust, Zig, Python, Odin, or anything else that can call a C
library. Download one zip, include one header, link one library.

> FlushTools began as a single-header C library for Raylib games. The Odin rewrite
> removes the compiler-specific macro layer (GCC nested functions, Clang Blocks,
> MSVC workarounds, `__attribute__((cleanup))`) and adds bounds checking,
> sanitizer-tested builds and automated releases.

## Contents

- [Features](#features)
- [Install](#install)
- [Quick start](#quick-start)
- [API reference](#api-reference)
- [Behaviour notes](#behaviour-notes)
- [Building from source](#building-from-source)
- [Testing](#testing)
- [Releases](#releases)
- [License](#license)

## Features

| Module | What it does |
|---|---|
| **Arena** | Bump allocator over a buffer you own. Alignment-correct, overflow-safe. |
| **Bit packing** | LSB-first bit writer/reader for compact network packets. Bounds-checked. |
| **Quantization** | Float to N-bit integer (1 to 32 bits) and back. 16-bit coordinate compression. |
| **Timer** | Monotonic, fractional-second timer with a per-second callback. |
| **Random** | SplitMix64: explicit-state generator and a per-thread, auto-seeded one. Unbiased ranges. |

Supported targets: 64-bit Linux, macOS (arm64) and Windows. Nothing in the library
allocates memory, prints, or calls `exit()`; failures are reported through return
values.

## Install

Every [release](../../releases) contains, for each platform, a zip with **only**
the header and that platform's library, plus the header on its own and checksums:

| Asset | Contents |
|---|---|
| `flushtools-<tag>-linux-x86_64.zip` | `flushtools.h`, `libflushtools.so` |
| `flushtools-<tag>-macos-arm64.zip` | `flushtools.h`, `libflushtools.dylib` |
| `flushtools-<tag>-windows-x86_64.zip` | `flushtools.h`, `flushtools.dll`, `flushtools.lib` (import library, required to link the DLL with MSVC) |
| `flushtools.h` | the header alone |
| `SHA256SUMS.txt` | SHA-256 checksums of all of the above |

Unzip next to your source and you are done.

## Quick start

### C

```c
#include "flushtools.h"
#include <stdio.h>

int main(void) {
    /* Pack a 3-bit value, then read it back. */
    uint8_t buf[16];
    fl_bit_writer w;
    fl_bit_writer_init(&w, buf, sizeof buf);
    fl_bit_writer_write(&w, 0x5, 3);

    fl_bit_reader r;
    fl_bit_reader_init(&r, buf, sizeof buf);
    printf("%u\n", fl_bit_reader_read(&r, 3));                  /* 5 */

    /* Squeeze a float in [0, 1] into 8 bits. */
    uint32_t q = fl_net_quantize(0.75f, 0.0f, 1.0f, 8);         /* 191 */
    printf("%u -> %f\n", q, fl_net_dequantize(q, 0.0f, 1.0f, 8)); /* ~0.749 */

    /* Roll a die. */
    printf("rolled %llu\n", (unsigned long long)fl_random_gen(1, 6));
    return 0;
}
```

Build it with the unzipped files in the same directory:

```sh
# Linux
cc main.c -I. -L. -lflushtools -Wl,-rpath,'$ORIGIN' -o main

# macOS
cc main.c -I. -L. -lflushtools -Wl,-rpath,@loader_path -o main

# Windows (MSVC): keep flushtools.dll next to the resulting .exe
cl main.c flushtools.lib
```

### C++

The header is wrapped in `extern "C"`, so just include it:

```cpp
#include "flushtools.h"
```

### Odin

Inside an Odin project you can skip the shared library and import the source:

```odin
import ft "flushtools/src"

main :: proc() {
    q := ft.net_quantize(0.75, 0, 1, 8)
}
```

### Arena

```c
uint64_t storage[64];                       /* any buffer you own */
fl_arena arena;
fl_arena_init(&arena, (uint8_t *)storage, sizeof storage);

int   *numbers = fl_arena_alloc(&arena, 10 * sizeof(int));        /* 8-byte aligned */
float *vectors = fl_arena_alloc_aligned(&arena, 64, 32);          /* 32-byte aligned */
if (!numbers || !vectors) { /* out of space */ }

fl_arena_reset(&arena);                     /* free everything at once */
```

### Timer

```c
static void on_tick(void *user_data) { printf("tick\n"); }

fl_timer t;
fl_timer_init(&t, 5);                       /* 5 seconds */
fl_timer_run(&t, on_tick, NULL);            /* blocks, calls on_tick about once per second */

/* or poll it yourself */
fl_timer_init(&t, 10);
while (!fl_timer_is_finished(&t)) {
    printf("%.2fs elapsed\n", fl_timer_get_elapsed(&t));
}
```

## API reference

All functions are declared in [`include/flushtools.h`](include/flushtools.h). A `bool`
return means `true` on success; `NULL` arguments and out-of-range values are rejected
rather than crashing.

### General

| Function | Description |
|---|---|
| `const char *fl_version(void)` | Library version. Matches `FLUSHTOOLS_VERSION` when header and binary agree. |

### Arena

| Function | Description |
|---|---|
| `void fl_arena_init(fl_arena*, uint8_t *buffer, size_t capacity)` | Start an arena over a caller-owned buffer. |
| `void *fl_arena_alloc(fl_arena*, size_t size)` | 8-byte-aligned allocation. `NULL` when full. Not zeroed. |
| `void *fl_arena_alloc_aligned(fl_arena*, size_t size, size_t alignment)` | Alignment must be a non-zero power of two. Applied to the real address. |
| `void fl_arena_reset(fl_arena*)` | Release all allocations; the buffer is untouched. |
| `size_t fl_arena_remaining(const fl_arena*)` | Bytes left, ignoring alignment padding. |

### Bit packing (LSB-first, 0 to 32 bits per call)

| Function | Description |
|---|---|
| `bool fl_bit_writer_init(fl_bit_writer*, uint8_t *buf, size_t byte_capacity)` | Zeroes the buffer. |
| `bool fl_bit_writer_write(fl_bit_writer*, uint32_t value, int count)` | All-or-nothing: `false` and nothing written if the bits do not fit. |
| `size_t fl_bit_writer_bytes_used(const fl_bit_writer*)` | Bytes to send. |
| `bool fl_bit_reader_init(fl_bit_reader*, const uint8_t *buf, size_t byte_length)` | |
| `uint32_t fl_bit_reader_read(fl_bit_reader*, int count)` | Returns 0 without advancing if fewer than `count` bits remain. |
| `uint64_t fl_bit_reader_remaining(const fl_bit_reader*)` | Bits left to read. |

### Quantization

`bits` must be 1 to 32 and `max > min`; otherwise quantize returns `0` and dequantize
returns `min`. Inputs are clamped to `[min, max]` and NaN is treated as `min`.

| Function | Description |
|---|---|
| `uint32_t fl_net_quantize(float value, float min, float max, int bits)` | Map a float onto `0 .. 2^bits - 1`. |
| `float fl_net_dequantize(uint32_t value, float min, float max, int bits)` | Inverse of the above. |
| `uint16_t fl_compress_coord(float value, float min, float max)` | 16-bit coordinate compression. |
| `float fl_decompress_coord(uint16_t value, float min, float max)` | Inverse of the above. |

### Timer

The clock is monotonic, so changing the system time does not affect it. Treat
`fl_timer` as opaque.

| Function | Description |
|---|---|
| `bool fl_timer_init(fl_timer*, int duration_seconds)` | Start the timer. `false` on negative duration. |
| `bool fl_timer_reset(fl_timer*, int duration_seconds)` | Same as init. |
| `double fl_timer_get_elapsed(const fl_timer*)` | Seconds since start. |
| `bool fl_timer_is_finished(const fl_timer*)` | `true` once the duration has elapsed. |
| `bool fl_timer_run(fl_timer*, fl_tick_callback, void *user_data)` | Blocks until finished, sleeping between checks. |

### Random

> **Not cryptographically secure.** Do not use for passwords, tokens or keys.

| Function | Description |
|---|---|
| `void fl_rng_seed(fl_rng*, uint64_t seed)` | Seed an explicit generator (reproducible sequences). |
| `uint64_t fl_rng_next(fl_rng*)` | Next 64-bit value. |
| `uint64_t fl_rng_range(fl_rng*, uint64_t min, uint64_t max)` | Inclusive and unbiased. Returns 0 if `max < min`. |
| `void fl_random_seed(uint64_t seed)` | Seed the calling thread's generator. |
| `uint64_t fl_random_gen(uint64_t min, uint64_t max)` | Per-thread generator, auto-seeded from the monotonic clock on first use. |

## Behaviour notes

Coming from the original C header? The wire formats (bit layout, quantization,
16-bit coordinates) are unchanged. These differences are deliberate:

| Area | Before (C header) | Now |
|---|---|---|
| Names | `net_quantize`, `compass_coord`, ... | `fl_` prefix; `compass_coord` became `fl_compress_coord` |
| Errors | `exit()` on bad input | Return `false` / `0` / `NULL`. The library never exits or prints. |
| Timer | Wall clock, whole seconds | Monotonic clock, fractional seconds |
| `timer_run` | Busy loop, printed to stdout | Sleeps between checks, silent, `callback(user_data)` |
| `random_gen` | Reseeded `srand` on every call; modulo bias | Seeded once per thread; unbiased; `fl_random_seed` for repeatability |
| Bit writer | Silently truncated | All-or-nothing, returns `bool` |
| Bit reader | No bounds check | Bounded; `fl_bit_reader_init` takes the buffer length |
| Quantize | Undefined behaviour at 32 bits and on NaN | 1 to 32 bits supported; NaN and bad ranges handled |
| Lambdas, `UNIQUE_VAR` | Macros | Removed (use `defer` in Odin, or your language's equivalent) |

Targets are 64-bit only; the struct layouts are asserted at compile time on the Odin
side and checked again by the C test.

## Building from source

You need [Odin](https://github.com/odin-lang/Odin/releases) (CI pins `dev-2026-09`).
A C compiler is needed for the ABI test, and `clang` for the sanitizer runs.

```sh
make            # build/libflushtools.so (or .dylib on macOS)
make test       # Odin unit tests
make test-c     # C program built from the public header, linked to the real library
make check      # both of the above
make asan       # AddressSanitizer + LeakSanitizer + UBSan
make tsan       # ThreadSanitizer
make clean
```

On Windows, from a shell where `odin` is on `PATH`:

```bat
build.bat         :: builds build\flushtools.dll and build\flushtools.lib
build.bat test    :: runs the Odin unit tests
```

### Project layout

```
src/                 Odin library (package flushtools), one file per module
include/flushtools.h public C header
tests/               Odin unit tests
tests/c/             C ABI test, thread test, sanitizer self-test
scripts/sanitize.sh  sanitizer runner used by `make asan|tsan` and CI
```

The header is maintained by hand. `tests/c/abi_test.c` compiles against it and links
the real library, so any drift between header and implementation fails CI.

## Testing

Every pull request runs the following, and every push to `master` repeats it before a
release can be published:

| Job | What it checks |
|---|---|
| `linux`, `macos`, `windows` | Odin unit tests, shared-library build, then a C program built from the public header and linked against the real `.so` / `.dylib` / `.dll`. This catches header and ABI drift and struct layout mismatches. |
| `sanitizers (asan)` | AddressSanitizer, LeakSanitizer and UBSan. The Odin library is built with `-sanitize:address`, the C tests with clang's matching flags, and the Odin tests run under ASan with Odin's tracking allocator. |
| `sanitizers (tsan)` | ThreadSanitizer over an 8-thread C test (per-thread RNG and timers). |

The ASan job also runs `tests/c/sanitizer_selftest.c`, which plants a heap overflow
inside the library and a leak, and **fails the build if the sanitizers do not catch
them**. A green run therefore cannot silently mean "the sanitizers are not working".

FlushTools never allocates memory itself, so leaks would come from calling code. The
main value of ASan and UBSan here is catching out-of-bounds access in the arena, bit
packing and quantizers.

Sanitizer jobs run on Linux only: LeakSanitizer is unavailable on Apple Silicon and
there is no equivalent on the Windows runner.

## Releases

Versioning and the changelog are automated with
[release-please](https://github.com/googleapis/release-please) and
[Conventional Commits](https://www.conventionalcommits.org):

| Commit | Version bump (while below 1.0.0) |
|---|---|
| `fix: ...` | patch |
| `feat: ...` | minor |
| `feat!: ...` or a `BREAKING CHANGE:` footer | minor (major once at 1.0.0 or above) |

Merging to `master` opens or updates a release PR. Merging that PR tags the release,
runs the full test matrix including the sanitizers, and attaches the per-platform
zips, the standalone header and `SHA256SUMS.txt` to the GitHub release. The version
in `src/flushtools.odin` and `include/flushtools.h` is bumped automatically through
`x-release-please-version` markers; do not edit it by hand.

### One-time repository setup

Under **Settings, Actions, General, Workflow permissions**, enable *Read and write
permissions* and *Allow GitHub Actions to create and approve pull requests*.

Pull requests opened with the default `GITHUB_TOKEN` do not trigger other workflows,
so CI will not run on the release PR itself. To have it run, give the
release-please step a personal access token through its `token:` input.

## License

[MIT](LICENSE). Copyright (c) 2026 Austin Clark.
