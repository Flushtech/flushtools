// FlushTools: small systems utilities exposed through a stable C ABI.
//
// Every `@(export)` procedure uses the "c" calling convention and a
// `fl_`-prefixed link name, so the shared library can be consumed from C, C++,
// Rust, Zig, Python (ctypes/cffi), Odin, and anything else with a C FFI.
//
// The matching C declarations live in include/flushtools.h. Keep the two in
// sync: tests/c/abi_test.c exercises the header against the built library.
//
// Note on `context`: procedures with the "c" calling convention receive no
// implicit Odin `context`. Anything that calls non-contextless Odin code first
// does `context = runtime.default_context()`.
package flushtools

// Updated automatically by release-please (see release-please-config.json).
VERSION :: "0.0.0" // x-release-please-version

@(export, link_name = "fl_version")
version :: proc "c" () -> cstring {
	return VERSION
}

// Guard against accidental ABI drift on the supported 64-bit targets.
when size_of(rawptr) == 8 {
	#assert(size_of(Arena) == 24)
	#assert(size_of(Array) == 32)
	#assert(size_of(String) == 24)
	#assert(size_of(Timer) == 16)
	#assert(size_of(Bit_Writer) == 24)
	#assert(size_of(Bit_Reader) == 24)
	#assert(size_of(Rng) == 8)
}
