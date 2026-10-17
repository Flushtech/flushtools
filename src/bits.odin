package flushtools

import "base:intrinsics"
import "core:c"

// LSB-first bit packing, compatible with the original flushtools.h wire format.

Bit_Writer :: struct {
	buffer:       [^]u8,
	current_bit:  u64,
	bit_capacity: u64,
}

Bit_Reader :: struct {
	buffer:       [^]u8,
	current_bit:  u64,
	bit_capacity: u64,
}

MAX_BITS_PER_OP :: 32

// Zero `buffer[0:byte_capacity]` and start writing at bit 0.
// Returns false if `writer` or `buffer` is NULL.
@(export, link_name = "fl_bit_writer_init")
bit_writer_init :: proc "c" (writer: ^Bit_Writer, buffer: [^]u8, byte_capacity: c.size_t) -> bool {
	if writer == nil || buffer == nil {
		return false
	}
	writer.buffer = buffer
	writer.current_bit = 0
	writer.bit_capacity = u64(byte_capacity) * 8
	intrinsics.mem_zero(rawptr(buffer), int(byte_capacity))
	return true
}

// Append the low `count` bits (0..32) of `value`.
// All-or-nothing: returns false and writes nothing if the bits do not fit or
// `count` is out of range.
@(export, link_name = "fl_bit_writer_write")
bit_writer_write :: proc "c" (writer: ^Bit_Writer, value: u32, count: c.int) -> bool {
	if writer == nil || writer.buffer == nil || count < 0 || count > MAX_BITS_PER_OP {
		return false
	}
	if writer.current_bit > writer.bit_capacity ||
	   writer.bit_capacity - writer.current_bit < u64(count) {
		return false
	}

	for i in 0 ..< u32(count) {
		if ((value >> i) & 1) != 0 {
			writer.buffer[writer.current_bit >> 3] |= u8(1) << u8(writer.current_bit & 7)
		}
		writer.current_bit += 1
	}
	return true
}

// Number of whole bytes touched so far (i.e. how many bytes to send).
@(export, link_name = "fl_bit_writer_bytes_used")
bit_writer_bytes_used :: proc "c" (writer: ^Bit_Writer) -> c.size_t {
	if writer == nil {
		return 0
	}
	return c.size_t((writer.current_bit + 7) / 8)
}

// Start reading `buffer[0:byte_length]` at bit 0.
// Returns false if `reader` or `buffer` is NULL.
@(export, link_name = "fl_bit_reader_init")
bit_reader_init :: proc "c" (reader: ^Bit_Reader, buffer: [^]u8, byte_length: c.size_t) -> bool {
	if reader == nil || buffer == nil {
		return false
	}
	reader.buffer = buffer
	reader.current_bit = 0
	reader.bit_capacity = u64(byte_length) * 8
	return true
}

// Bits left to read.
@(export, link_name = "fl_bit_reader_remaining")
bit_reader_remaining :: proc "c" (reader: ^Bit_Reader) -> u64 {
	if reader == nil || reader.current_bit > reader.bit_capacity {
		return 0
	}
	return reader.bit_capacity - reader.current_bit
}

// Read `count` bits (0..32). Returns 0 without advancing if fewer than `count`
// bits remain or `count` is out of range; check fl_bit_reader_remaining first
// when a zero value is ambiguous.
@(export, link_name = "fl_bit_reader_read")
bit_reader_read :: proc "c" (reader: ^Bit_Reader, count: c.int) -> u32 {
	if reader == nil || reader.buffer == nil || count < 0 || count > MAX_BITS_PER_OP {
		return 0
	}
	if bit_reader_remaining(reader) < u64(count) {
		return 0
	}

	value: u32
	for i in 0 ..< u32(count) {
		bit := (reader.buffer[reader.current_bit >> 3] >> u8(reader.current_bit & 7)) & 1
		value |= u32(bit) << i
		reader.current_bit += 1
	}
	return value
}
