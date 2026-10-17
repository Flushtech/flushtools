# FlushTools build (Linux / macOS). On Windows use build.bat or the CI commands.
#
#   make            build the shared library into build/
#   make test       run Odin unit tests
#   make test-c     build the C ABI test against the library and run it
#   make check      test + test-c
#   make asan       AddressSanitizer + LeakSanitizer + UBSan (needs clang)
#   make tsan       ThreadSanitizer (needs clang)
#   make clean

ODIN       ?= odin
ODIN_FLAGS ?= -o:speed -vet -strict-style
CC         ?= cc
BUILD      := build

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  LIBEXT := dylib
else
  LIBEXT := so
endif
LIB := $(BUILD)/libflushtools.$(LIBEXT)

SRC := $(wildcard src/*.odin)

.PHONY: all test test-c check asan tsan clean
all: $(LIB)

$(LIB): $(SRC)
	@mkdir -p $(BUILD)
	$(ODIN) build src -build-mode:dll -out:$(LIB) $(ODIN_FLAGS)

test:
	$(ODIN) test tests -vet -strict-style

test-c: $(LIB)
	$(CC) -std=c99 -Wall -Wextra -Wpedantic -Werror -Iinclude tests/c/abi_test.c \
		-L$(BUILD) -lflushtools -lm -o $(BUILD)/abi_test
	LD_LIBRARY_PATH=$(BUILD) DYLD_LIBRARY_PATH=$(BUILD) ./$(BUILD)/abi_test

check: test test-c

asan:
	bash scripts/sanitize.sh asan

tsan:
	bash scripts/sanitize.sh tsan

clean:
	rm -rf $(BUILD)
