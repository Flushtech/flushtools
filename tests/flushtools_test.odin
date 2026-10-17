package tests

import "core:c"
import "core:math"
import "core:testing"

import fl "../src"

@(test)
test_arena :: proc(t: ^testing.T) {
	storage: [8]u64 // 64 bytes, 8-byte aligned
	base := cast([^]u8)raw_data(storage[:])

	a: fl.Arena
	fl.arena_init(&a, base, 64)

	p1 := fl.arena_alloc(&a, 10)
	p2 := fl.arena_alloc(&a, 8)
	testing.expect(t, p1 == rawptr(base), "first allocation starts at the buffer")
	testing.expect(t, p2 != nil && uintptr(p2) % 8 == 0, "second allocation is 8-aligned")
	testing.expect(t, a.offset == 24, "10 bytes + 6 padding + 8 bytes")

	testing.expect(t, fl.arena_alloc(&a, 41) == nil, "over-allocation fails")
	testing.expect(t, fl.arena_alloc(&a, 40) != nil, "exact fit succeeds")
	testing.expect(t, fl.arena_remaining(&a) == 0, "arena is full")
	testing.expect(t, fl.arena_alloc(&a, 1) == nil, "full arena fails")

	fl.arena_reset(&a)
	testing.expect(t, fl.arena_remaining(&a) == 64, "reset reclaims everything")

	p3 := fl.arena_alloc_aligned(&a, 4, 32)
	testing.expect(t, p3 != nil && uintptr(p3) % 32 == 0, "32-byte alignment honoured")
	testing.expect(t, fl.arena_alloc_aligned(&a, 4, 3) == nil, "non power-of-two alignment rejected")
	testing.expect(t, fl.arena_alloc_aligned(&a, 4, 0) == nil, "zero alignment rejected")
	testing.expect(t, fl.arena_alloc_aligned(nil, 4, 8) == nil, "nil arena rejected")
	testing.expect(t, fl.arena_alloc(&a, max(c.size_t)) == nil, "huge size cannot overflow")
}

@(test)
test_arena_unaligned_buffer :: proc(t: ^testing.T) {
	storage: [8]u64
	base := cast([^]u8)raw_data(storage[:])

	a: fl.Arena
	fl.arena_init(&a, base[1:], 40) // deliberately misaligned start
	p := fl.arena_alloc(&a, 8)
	testing.expect(t, p != nil && uintptr(p) % 8 == 0, "alignment is applied to the real address")
}

@(test)
test_bits_roundtrip :: proc(t: ^testing.T) {
	buf: [16]u8
	w: fl.Bit_Writer
	testing.expect(t, fl.bit_writer_init(&w, raw_data(buf[:]), 16), "writer init")
	testing.expect(t, fl.bit_writer_write(&w, 5, 3), "write 3 bits")
	testing.expect(t, buf[0] == 5, "LSB-first layout")
	testing.expect(t, fl.bit_writer_write(&w, 0x1ABCD, 17), "write 17 bits")
	testing.expect(t, fl.bit_writer_write(&w, 0xDEADBEEF, 32), "write 32 bits")
	testing.expect(t, fl.bit_writer_bytes_used(&w) == 7, "52 bits -> 7 bytes")

	r: fl.Bit_Reader
	testing.expect(t, fl.bit_reader_init(&r, raw_data(buf[:]), 16), "reader init")
	testing.expect(t, fl.bit_reader_read(&r, 3) == 5, "read 3")
	testing.expect(t, fl.bit_reader_read(&r, 17) == 0x1ABCD, "read 17")
	testing.expect(t, fl.bit_reader_read(&r, 32) == 0xDEADBEEF, "read 32")
	testing.expect(t, fl.bit_reader_remaining(&r) == 128 - 52, "remaining bits")
}

@(test)
test_bits_limits :: proc(t: ^testing.T) {
	one: [1]u8
	w: fl.Bit_Writer
	testing.expect(t, fl.bit_writer_init(&w, raw_data(one[:]), 1), "init")
	testing.expect(t, fl.bit_writer_write(&w, 0xFF, 8), "fills the buffer")
	testing.expect(t, !fl.bit_writer_write(&w, 1, 1), "no room")
	testing.expect(t, !fl.bit_writer_write(&w, 1, 33), "count > 32 rejected")
	testing.expect(t, !fl.bit_writer_write(&w, 1, -1), "negative count rejected")
	testing.expect(t, one[0] == 0xFF, "failed writes leave the buffer untouched")

	testing.expect(t, !fl.bit_writer_init(nil, raw_data(one[:]), 1), "nil writer")
	testing.expect(t, !fl.bit_writer_init(&w, nil, 1), "nil buffer")

	r: fl.Bit_Reader
	testing.expect(t, fl.bit_reader_init(&r, raw_data(one[:]), 1), "reader init")
	testing.expect(t, fl.bit_reader_read(&r, 8) == 0xFF, "read all bits")
	testing.expect(t, fl.bit_reader_read(&r, 1) == 0, "reading past the end returns 0")
	testing.expect(t, fl.bit_reader_remaining(&r) == 0, "nothing remains")
}

@(test)
test_quantize :: proc(t: ^testing.T) {
	q := fl.net_quantize(0.75, 0, 1, 8)
	testing.expect(t, q == 191, "README example")
	testing.expect(t, abs(fl.net_dequantize(q, 0, 1, 8) - 0.75) < 1.0 / 255.0, "round trip")
	testing.expect(t, fl.net_quantize(-5, 0, 1, 8) == 0, "clamps low")
	testing.expect(t, fl.net_quantize(5, 0, 1, 8) == 255, "clamps high")
	testing.expect(t, fl.net_quantize(1, 0, 1, 32) == max(u32), "32 bits does not overflow")
	testing.expect(t, fl.net_quantize(0.5, 0, 1, 0) == 0, "bits < 1 rejected")
	testing.expect(t, fl.net_quantize(0.5, 0, 1, 33) == 0, "bits > 32 rejected")
	testing.expect(t, fl.net_quantize(0.5, 1, 1, 8) == 0, "empty range rejected")
	testing.expect(t, fl.net_quantize(math.nan_f32(), 0, 1, 8) == 0, "NaN maps to min")
	testing.expect(t, fl.net_dequantize(1000, 0, 1, 8) == 1, "out-of-range value clamps")
}

@(test)
test_coords :: proc(t: ^testing.T) {
	packed := fl.compress_coord(123.4, 0, 1000)
	testing.expect(t, abs(fl.decompress_coord(packed, 0, 1000) - 123.4) < 0.02, "round trip")
	testing.expect(t, fl.compress_coord(0, 0, 1000) == 0, "min")
	testing.expect(t, fl.compress_coord(1000, 0, 1000) == 65535, "max")
	testing.expect(t, fl.compress_coord(-50, 0, 1000) == 0, "clamps low")
	testing.expect(t, fl.compress_coord(5000, 0, 1000) == 65535, "clamps high")
}

@(test)
test_timer :: proc(t: ^testing.T) {
	timer: fl.Timer
	testing.expect(t, !fl.timer_init(&timer, -1), "negative duration rejected")
	testing.expect(t, !fl.timer_init(nil, 1), "nil timer rejected")

	testing.expect(t, fl.timer_init(&timer, 0), "zero duration is valid")
	testing.expect(t, fl.timer_is_finished(&timer), "zero duration finishes immediately")

	testing.expect(t, fl.timer_init(&timer, 100), "init")
	testing.expect(t, !fl.timer_is_finished(&timer), "not finished yet")
	testing.expect(t, fl.timer_get_elapsed(&timer) < 1, "barely any time elapsed")
	testing.expect(t, fl.timer_is_finished(nil), "nil timer counts as finished")
}

count_tick :: proc "c" (user_data: rawptr) {
	(^int)(user_data)^ += 1
}

@(test)
test_timer_run :: proc(t: ^testing.T) {
	timer: fl.Timer
	ticks: int
	testing.expect(t, fl.timer_init(&timer, 2), "init")
	testing.expect(t, fl.timer_run(&timer, count_tick, &ticks), "run completes")
	testing.expect(t, fl.timer_is_finished(&timer), "finished after run")
	testing.expect(t, ticks >= 1 && ticks <= 2, "about one tick per second")
	testing.expect(t, !fl.timer_run(&timer, nil, nil), "nil callback rejected")
}

@(test)
test_rng :: proc(t: ^testing.T) {
	a, b: fl.Rng
	fl.rng_seed(&a, 42)
	fl.rng_seed(&b, 42)
	for _ in 0 ..< 100 {
		testing.expect(t, fl.rng_next(&a) == fl.rng_next(&b), "same seed, same sequence")
	}

	counts: [6]int
	for _ in 0 ..< 10000 {
		v := fl.rng_range(&a, 1, 6)
		testing.expect(t, v >= 1 && v <= 6, "die roll in range")
		if v >= 1 && v <= 6 {
			counts[v - 1] += 1
		}
	}
	for c in counts {
		testing.expect(t, c > 1400 && c < 1950, "roughly uniform")
	}

	testing.expect(t, fl.rng_range(&a, 5, 5) == 5, "degenerate range")
	testing.expect(t, fl.rng_range(&a, 9, 3) == 0, "inverted range returns 0")
	_ = fl.rng_range(&a, 0, max(u64)) // full span must not hang
}

@(test)
test_random_gen :: proc(t: ^testing.T) {
	for _ in 0 ..< 1000 {
		v := fl.random_gen(10, 20)
		testing.expect(t, v >= 10 && v <= 20, "in range")
	}
	fl.random_seed(7)
	first := fl.random_gen(0, 1_000_000)
	fl.random_seed(7)
	testing.expect(t, fl.random_gen(0, 1_000_000) == first, "reseeding reproduces the sequence")
}

@(test)
test_version :: proc(t: ^testing.T) {
	testing.expect(t, string(fl.version()) == fl.VERSION, "version string")
}
