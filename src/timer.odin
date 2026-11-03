package flushtools

import "base:runtime"
import "core:c"
import "core:time"

// Monotonic timer (immune to wall-clock changes) with fractional-second
// resolution. Treat the struct as opaque; use the fl_timer_* functions.
Timer :: struct {
	start_ns:  i64,
	duration:  c.int,
	_reserved: c.int,
}

Tick_Callback :: proc "c" (user_data: rawptr)

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

@(export, link_name = "fl_timer_reset")
timer_reset :: proc "c" (timer: ^Timer, new_duration_seconds: c.int) -> bool {
	return timer_init(timer, new_duration_seconds)
}

@(export, link_name = "fl_timer_get_elapsed")
timer_get_elapsed :: proc "c" (timer: ^Timer) -> f64 {
	context = runtime.default_context()
	if timer == nil {
		return 0
	}
	start := time.Tick{_nsec = timer.start_ns}
	return time.duration_seconds(time.tick_diff(start, time.tick_now()))
}

@(export, link_name = "fl_timer_is_finished")
timer_is_finished :: proc "c" (timer: ^Timer) -> bool {
	if timer == nil {
		return true
	}
	return timer_get_elapsed(timer) >= f64(timer.duration)
}

@(export, link_name = "fl_timer_run")
timer_run :: proc "c" (timer: ^Timer, callback: Tick_Callback, user_data: rawptr) -> bool {
	context = runtime.default_context()
	if timer == nil || callback == nil {
		return false
	}

	last := time.tick_now()
	for {
		now := time.tick_now()
		if time.duration_seconds(time.tick_diff(last, now)) >= 1 {
			callback(user_data)
			last = now
		}
		if timer_is_finished(timer) {
			break
		}
		time.sleep(5 * time.Millisecond)
	}
	return true
}
