package flushtools

import "core:c"

// Float <-> integer compression for bandwidth-sensitive data.
// Math is done in f64 internally so 32-bit quantization stays accurate.

@(private = "file")
level_count :: proc "contextless" (bits: c.int) -> f64 {
	return f64((u64(1) << u64(bits)) - 1)
}

// Clamp `value` to [min_val, max_val] and map it onto [0, 1].
// NaN and degenerate ranges map to 0.
@(private = "file")
normalize :: proc "contextless" (value, min_val, max_val: f32) -> f64 {
	v := value
	if v != v { 	// NaN
		v = min_val
	}
	n := (f64(v) - f64(min_val)) / (f64(max_val) - f64(min_val))
	if !(n >= 0) { 	// also catches NaN from degenerate input
		return 0
	}
	if n > 1 {
		return 1
	}
	return n
}

// Map `value` (clamped to [min_val, max_val]) onto 0 .. 2^bits - 1.
// `bits` must be 1..32 and max_val > min_val; otherwise returns 0.
@(export, link_name = "fl_net_quantize")
net_quantize :: proc "c" (value, min_val, max_val: f32, bits: c.int) -> u32 {
	if bits < 1 || bits > 32 || !(max_val > min_val) {
		return 0
	}
	levels := level_count(bits)
	return u32(normalize(value, min_val, max_val) * levels + 0.5)
}

// Inverse of fl_net_quantize. Invalid arguments return `min_val`.
@(export, link_name = "fl_net_dequantize")
net_dequantize :: proc "c" (value: u32, min_val, max_val: f32, bits: c.int) -> f32 {
	if bits < 1 || bits > 32 || !(max_val > min_val) {
		return min_val
	}
	n := f64(value) / level_count(bits)
	if n > 1 {
		n = 1
	}
	return f32(f64(min_val) + n * (f64(max_val) - f64(min_val)))
}

// 16-bit coordinate compression (truncating, as in the original header).
@(export, link_name = "fl_compress_coord")
compress_coord :: proc "c" (value, min_val, max_val: f32) -> u16 {
	if !(max_val > min_val) {
		return 0
	}
	return u16(normalize(value, min_val, max_val) * 65535.0)
}

@(export, link_name = "fl_decompress_coord")
decompress_coord :: proc "c" (value: u16, min_val, max_val: f32) -> f32 {
	if !(max_val > min_val) {
		return min_val
	}
	n := f64(value) / 65535.0
	return f32(f64(min_val) + n * (f64(max_val) - f64(min_val)))
}
