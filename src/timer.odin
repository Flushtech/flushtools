package flushtools

import "base:runtime"
import "core:c"
import "core:time"

// Monotonic timer (immune to wall-clock changes) with fractional-second
// resolution. `start_ns` is an opaque monotonic timestamp; treat the struct as
// opaque and only touch it through the fl_timer_* functions.
Timer :: struct {
	start_ns:  i64,
	duration:  c.int, // seconds
	_reserved: c.int,
}

// Called roughly once per second by fl_timer_run.
Tick_Callback :: proc "c" (user_data: rawptr)

// Start (or restart) `timer` for `duration_seconds`.
// Returns false if `timer` is NULL or the duration is negative.
@(export, link_name = "fl_timer_init")
timer_init :: proc "c" (timer: ^Timer, duration_seconds: c.int) -> bool {
	context = runtime.default_context()
	if timer == nil || duration_seconds < 0 {
		return false
	}
	timer.duration = duration_seconds
	timer.start_ns = time.tick_now()._nsec
	return true
}

// Same as fl_timer_init; kept for parity with the original API.
@(export, link_name = "fl_timer_reset")
timer_reset :: proc "c" (timer: ^Timer, new_duration_seconds: c.int) -> bool {
	return timer_init(timer, new_duration_seconds)
}

// Seconds since the timer was started.
@(export, link_name = "fl_timer_get_elapsed")
timer_get_elapsed :: proc "c" (timer: ^Timer) -> f64 {
	context = runtime.default_context()
	if timer == nil {
		return 0
	}
	start := time.Tick{_nsec = timer.start_ns}
	return time.duration_seconds(time.tick_diff(start, time.tick_now()))
}

// True once `duration` seconds have elapsed. A NULL timer counts as finished.
@(export, link_name = "fl_timer_is_finished")
timer_is_finished :: proc "c" (timer: ^Timer) -> bool {
	if timer == nil {
		return true
	}
	return timer_get_elapsed(timer) >= f64(timer.duration)
}

// Block until the timer finishes, invoking `callback(user_data)` about once per
// second. Sleeps between checks (no busy-waiting). Returns false if `timer` or
// `callback` is NULL.
@(export, link_name = "fl_timer_run")
timer_run :: proc "c" (timer: ^Timer, callback: Tick_Callback, user_data: rawptr) -> bool {
	context = runtime.default_context()
	if timer == nil || callback == nil {
		return false
	}

	last := time.tick_now()
	for !timer_is_finished(timer) {
		now := time.tick_now()
		if time.duration_seconds(time.tick_diff(last, now)) >= 1 {
			callback(user_data)
			last = now
		}
		time.sleep(5 * time.Millisecond)
	}
	return true
}
