package flushtools

import "core:c"

// Bump allocator over a caller-provided buffer. FlushTools never allocates or
// frees the backing memory; the caller owns it.
Arena :: struct {
	buffer:   [^]u8,
	capacity: c.size_t,
	offset:   c.size_t,
}

DEFAULT_ALIGNMENT :: 8

// Initialise `arena` over `buffer[0:capacity]`. A NULL buffer yields an arena
// that always fails to allocate.
@(export, link_name = "fl_arena_init")
arena_init :: proc "c" (arena: ^Arena, buffer: [^]u8, capacity: c.size_t) {
	if arena == nil {
		return
	}
	arena.buffer = buffer
	arena.capacity = capacity if buffer != nil else 0
	arena.offset = 0
}

// Allocate `size` bytes aligned to `alignment` (a non-zero power of two).
// Alignment is applied to the real address, not just the offset, so it is
// correct even when the backing buffer itself is not aligned.
// Returns NULL when out of space or on invalid arguments. Memory is not zeroed.
@(export, link_name = "fl_arena_alloc_aligned")
arena_alloc_aligned :: proc "c" (arena: ^Arena, size: c.size_t, alignment: c.size_t) -> rawptr {
	if arena == nil || arena.buffer == nil {
		return nil
	}
	if alignment == 0 || (alignment & (alignment - 1)) != 0 {
		return nil
	}
	if arena.offset > arena.capacity {
		return nil
	}

	remaining := arena.capacity - arena.offset
	current := uintptr(arena.buffer) + uintptr(arena.offset)
	mask := uintptr(alignment) - 1
	padding := (uintptr(alignment) - (current & mask)) & mask

	if c.size_t(padding) > remaining || size > remaining - c.size_t(padding) {
		return nil
	}

	arena.offset += c.size_t(padding) + size
	return rawptr(current + padding)
}

// Allocate `size` bytes with 8-byte alignment.
@(export, link_name = "fl_arena_alloc")
arena_alloc :: proc "c" (arena: ^Arena, size: c.size_t) -> rawptr {
	return arena_alloc_aligned(arena, size, DEFAULT_ALIGNMENT)
}

// Release every allocation at once. The backing buffer is left untouched.
@(export, link_name = "fl_arena_reset")
arena_reset :: proc "c" (arena: ^Arena) {
	if arena == nil {
		return
	}
	arena.offset = 0
}

// Bytes still available (ignoring any alignment padding a request may need).
@(export, link_name = "fl_arena_remaining")
arena_remaining :: proc "c" (arena: ^Arena) -> c.size_t {
	if arena == nil || arena.offset > arena.capacity {
		return 0
	}
	return arena.capacity - arena.offset
}

// Save the current allocation offset for a later rewind.
@(export, link_name = "fl_arena_mark")
arena_mark :: proc "c" (arena: ^Arena) -> c.size_t {
	if arena == nil || arena.offset > arena.capacity {
		return 0
	}
	return arena.offset
}

// Rewind to an earlier mark. Marks beyond the current offset are rejected.
@(export, link_name = "fl_arena_rewind")
arena_rewind :: proc "c" (arena: ^Arena, mark: c.size_t) -> bool {
	if arena == nil || arena.offset > arena.capacity || mark > arena.offset {
		return false
	}
	arena.offset = mark
	return true
}
