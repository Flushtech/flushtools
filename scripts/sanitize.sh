#!/usr/bin/env bash
# Sanitizer runs for FlushTools (Linux; macOS ASan works but LeakSanitizer is
# unavailable on Apple Silicon).
#
#   scripts/sanitize.sh asan   AddressSanitizer + LeakSanitizer + UBSan
#   scripts/sanitize.sh tsan   ThreadSanitizer
#
# The Odin library itself is built with -sanitize:<mode>, and the C test
# programs with the matching clang -fsanitize flags, so bugs are caught inside
# the Odin code as well as at the boundary.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-asan}"
ODIN="${ODIN:-odin}"
CC_SAN="${CC_SAN:-clang}"
out="build/$mode"
rm -rf "$out"
mkdir -p "$out"

# Odin requires (and Windows mandates) an explicit extension on -out for DLLs.
if [ "$(uname -s)" = "Darwin" ]; then
  libext=dylib
else
  libext=so
fi

case "$mode" in
  asan)
    odin_san=address
    c_san="-fsanitize=address,undefined -fno-sanitize-recover=undefined"
    ;;
  tsan)
    odin_san=thread
    c_san="-fsanitize=thread"
    ;;
  *)
    echo "usage: $0 asan|tsan" >&2
    exit 2
    ;;
esac

cflags="-std=c99 -g -O1 -fno-omit-frame-pointer -Iinclude $c_san"
link="-L$out -lflushtools -lm -lpthread -Wl,-rpath,$PWD/$out"

echo "==> [$mode] building libflushtools with -sanitize:$odin_san"
"$ODIN" build src -build-mode:dll -out:"$out/libflushtools.$libext" -o:none -debug \
  -sanitize:"$odin_san" -vet -strict-style

if [ "$mode" = "asan" ]; then
  export ASAN_OPTIONS="detect_leaks=1:strict_string_checks=1:detect_stack_use_after_return=1:abort_on_error=0"
  export UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1"

  echo "==> [asan] Odin unit tests (ASan + Odin tracking allocator)"
  "$ODIN" test tests -debug -sanitize:address -vet -strict-style

  echo "==> [asan] C ABI test (ASan + UBSan + LeakSanitizer)"
  # shellcheck disable=SC2086
  "$CC_SAN" $cflags tests/c/abi_test.c $link -o "$out/abi_test"
  "$out/abi_test"

  echo "==> [asan] self-test: sanitizers must catch deliberate bugs"
  # shellcheck disable=SC2086
  "$CC_SAN" $cflags tests/c/sanitizer_selftest.c $link -o "$out/selftest"
  expect_catch() { # <mode> <expected text in sanitizer report>
    local output code
    set +e
    output="$("$out/selftest" "$1" 2>&1)"
    code=$?
    set -e
    if [ "$code" -eq 0 ] || ! grep -q "$2" <<<"$output"; then
      echo "$output"
      echo "FAIL: sanitizer did not catch the deliberate '$1' bug" >&2
      exit 1
    fi
    echo "    ok: caught deliberate '$1' ($2)"
  }
  expect_catch overflow "heap-buffer-overflow"
  expect_catch leak "LeakSanitizer: detected memory leaks"
else
  export TSAN_OPTIONS="halt_on_error=1:second_deadlock_stack=1"

  echo "==> [tsan] Odin unit tests"
  "$ODIN" test tests -debug -sanitize:thread -vet -strict-style

  echo "==> [tsan] multithreaded C test"
  # shellcheck disable=SC2086
  "$CC_SAN" $cflags tests/c/thread_test.c $link -o "$out/thread_test"
  "$out/thread_test"
fi

echo "==> [$mode] all clean"
