package flushtools

import "base:runtime"
import "core:time"

// Fast NON-CRYPTOGRAPHIC random numbers (SplitMix64).
// Do not use for passwords, tokens, keys, or anything security-sensitive.

// Explicit generator state, for reproducible or thread-owned sequences.
Rng :: struct {
	state: u64,
}

@(private = "file")
splitmix64 :: proc "contextless" (state: ^u64) -> u64 {
	state^ += 0x9E3779B97F4A7C15
	z := state^
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

@(export, link_name = "fl_rng_seed")
rng_seed :: proc "c" (rng: ^Rng, seed: u64) {
	if rng == nil {
		return
	}
	rng.state = seed
}

@(export, link_name = "fl_rng_next")
rng_next :: proc "c" (rng: ^Rng) -> u64 {
	if rng == nil {
		return 0
	}
	return splitmix64(&rng.state)
}

// Uniform value in [min_val, max_val], inclusive, without modulo bias.
// Returns 0 if max_val < min_val (matches the original header).
@(export, link_name = "fl_rng_range")
rng_range :: proc "c" (rng: ^Rng, min_val, max_val: u64) -> u64 {
	if rng == nil || max_val < min_val {
		return 0
	}
	span := max_val - min_val + 1 // wraps to 0 when the range is the full u64
	if span == 0 {
		return rng_next(rng)
	}
	threshold := (~u64(0) - span + 1) % span // == 2^64 mod span
	for {
		x := rng_next(rng)
		if x >= threshold {
			return min_val + x % span
		}
	}
}

// Per-thread generator, lazily seeded from the monotonic clock.
@(private = "file", thread_local)
g_rng: Rng

@(private = "file", thread_local)
g_rng_seeded: bool

// Seed the calling thread's generator (for reproducible sequences).
@(export, link_name = "fl_random_seed")
random_seed :: proc "c" (seed: u64) {
	rng_seed(&g_rng, seed)
	g_rng_seeded = true
}

// Uniform value in [min_val, max_val] from the calling thread's generator.
// Unlike the original header this seeds once per thread (not on every call),
// so rapid successive calls no longer return correlated values.
@(export, link_name = "fl_random_gen")
random_gen :: proc "c" (min_val, max_val: u64) -> u64 {
	context = runtime.default_context()
	if !g_rng_seeded {
		random_seed(u64(time.tick_now()._nsec) ~ u64(uintptr(&g_rng)))
	}
	return rng_range(&g_rng, min_val, max_val)
}
