package flushtools

import "core:c"

// Caller-owned, fixed-capacity, null-terminated UTF-8/byte string.
String :: struct {
	data:     [^]u8,
	length:   c.size_t,
	capacity: c.size_t,
}

// Initialise an empty string. Capacity includes space for the trailing NUL.
@(export, link_name = "fl_string_init")
string_init :: proc "c" (s: ^String, data: [^]u8, capacity: c.size_t) -> bool {
	if s == nil || data == nil || capacity == 0 {
		return false
	}
	s.data = data
	s.length = 0
	s.capacity = capacity
	s.data[0] = 0
	return true
}

// Append a null-terminated string. Failure leaves the destination unchanged.
@(export, link_name = "fl_string_append")
string_append :: proc "c" (s: ^String, value: cstring) -> bool {
	if s == nil || value == nil || s.data == nil ||
	   s.capacity == 0 || s.length >= s.capacity {
		return false
	}

	source := cast([^]u8)value
	value_length: c.size_t
	for source[value_length] != 0 {
		value_length += 1
	}
	if value_length > s.capacity - s.length - 1 {
		return false
	}

	for i in 0 ..< value_length {
		s.data[s.length + i] = source[i]
	}
	s.length += value_length
	s.data[s.length] = 0
	return true
}

// Clear the string without modifying the rest of its buffer.
@(export, link_name = "fl_string_clear")
string_clear :: proc "c" (s: ^String) {
	if s == nil || s.data == nil || s.capacity == 0 {
		return
	}
	s.length = 0
	s.data[0] = 0
}
