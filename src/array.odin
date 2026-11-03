package flushtools

import "core:c"

// Caller-owned, fixed-capacity array. Elements are stored contiguously as
// element_size-byte values; data must be suitably aligned for the element type.
Array :: struct {
	data:         [^]u8,
	count:        c.size_t,
	capacity:     c.size_t,
	element_size: c.size_t,
}

// Initialise an array over caller-owned storage. A zero-capacity array may
// use a nil data pointer. Returns false for invalid arguments or size overflow.
@(export, link_name = "fl_array_init")
array_init :: proc "c" (array: ^Array, data: [^]u8, capacity, element_size: c.size_t) -> bool {
	if array == nil || element_size == 0 || (capacity > 0 && data == nil) {
		return false
	}
	if capacity > max(c.size_t) / element_size {
		return false
	}
	array.data = data
	array.count = 0
	array.capacity = capacity
	array.element_size = element_size
	return true
}

// Append one element by value. element must point to element_size readable
// bytes and must not alias the array's backing storage.
@(export, link_name = "fl_array_push")
array_push :: proc "c" (array: ^Array, element: rawptr) -> bool {
	if array == nil || element == nil || array.data == nil ||
	   array.element_size == 0 || array.count >= array.capacity {
		return false
	}
	source := cast([^]u8)element
	offset := array.count * array.element_size
	for i in 0 ..< array.element_size {
		array.data[offset + i] = source[i]
	}
	array.count += 1
	return true
}

// Insert one element before index. index == count appends to the end.
@(export, link_name = "fl_array_insert")
array_insert :: proc "c" (array: ^Array, index: c.size_t, element: rawptr) -> bool {
	if array == nil || element == nil || array.data == nil ||
	   array.element_size == 0 || index > array.count ||
	   array.count >= array.capacity {
		return false
	}
	source := cast([^]u8)element
	for i := array.count; i > index; i -= 1 {
		dst_offset := i * array.element_size
		src_offset := (i - 1) * array.element_size
		for j in 0 ..< array.element_size {
			array.data[dst_offset + j] = array.data[src_offset + j]
		}
	}
	offset := index * array.element_size
	for i in 0 ..< array.element_size {
		array.data[offset + i] = source[i]
	}
	array.count += 1
	return true
}

// Remove an element and preserve the order of the remaining elements.
@(export, link_name = "fl_array_remove")
array_remove :: proc "c" (array: ^Array, index: c.size_t) -> bool {
	if array == nil || array.data == nil || array.element_size == 0 ||
	   index >= array.count {
		return false
	}
	for i := index; i + 1 < array.count; i += 1 {
		dst_offset := i * array.element_size
		src_offset := (i + 1) * array.element_size
		for j in 0 ..< array.element_size {
			array.data[dst_offset + j] = array.data[src_offset + j]
		}
	}
	array.count -= 1
	return true
}

// Return a pointer to the element at index, or nil when out of bounds.
@(export, link_name = "fl_array_at")
array_at :: proc "c" (array: ^Array, index: c.size_t) -> rawptr {
	if array == nil || array.data == nil || array.element_size == 0 ||
	   index >= array.count {
		return nil
	}
	return rawptr(&array.data[index * array.element_size])
}

// Remove all elements without modifying their storage.
@(export, link_name = "fl_array_clear")
array_clear :: proc "c" (array: ^Array) {
	if array == nil {
		return
	}
	array.count = 0
}
