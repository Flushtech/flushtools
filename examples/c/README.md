# C getting-started example

This is a small C application that uses the **public** `include/flushtools.h`
header and links to the real FlushTools shared library. It demonstrates the
same integration path an application uses; it does not compile or copy the
Odin implementation into the example.

The program exercises:

- `fl_version()` to check which library is loaded
- caller-owned arena allocation and reset
- bit packing and unpacking
- float quantization and dequantization
- a seeded, reproducible RNG
- the monotonic timer

The RNG is **not cryptographically secure**.

## Build from a source checkout

Build the shared library first from the repository root:

```sh
make
```

Then build and run the example:

```sh
make -C examples/c
make -C examples/c run
```

Requirements: a C compiler and Make. The library is loaded from the repository's
`build/` directory at runtime.

On Windows, open a Developer Command Prompt with Odin and MSVC available, then run:

```bat
build.bat
examples\c\build.bat
```

The executable is written to `build\c_example.exe`; the script adds the library
build directory to `PATH` when running it.

## Build using a release download

Download the **full bundle** for your platform from the
[FlushTools releases](../../releases). It contains the public header and the
shared library (plus the MSVC import library on Windows).

Put `main.c` from this directory beside the extracted `flushtools.h` and
library files, then compile:

**Linux**

```sh
cc -std=c11 -Wall -Wextra -Wpedantic -I. main.c -L. -lflushtools \
  -Wl,-rpath,'$ORIGIN' -o c_example
./c_example
```

**Windows (MSVC Developer Command Prompt)**

```bat
cl /nologo /W4 /I. main.c flushtools.lib /Fe:c_example.exe
c_example.exe
```

Keep `flushtools.dll` next to `c_example.exe` when running on Windows.

## Expected output

The exact timer value and random roll can vary if you change the seed. With the
sample seed, the program prints the loaded library version, the arena values,
the packed value, the quantization round-trip, a die roll, and elapsed time.
