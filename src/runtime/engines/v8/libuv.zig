//! libuv FFI Bindings
//!
//! Minimal bindings to libuv for timer support.
//! Only includes what's needed for setTimeout/clearTimeout.

const std = @import("std");

// ============================================================================
// libuv Types
// ============================================================================

/// Opaque handle to a libuv event loop.
pub const uv_loop_t = opaque {};

/// libuv timer handle.
/// This is a simplified representation - we treat it as opaque and use
/// the C functions to manipulate it.
pub const uv_timer_t = extern struct {
    /// User data pointer - we use this to store our callback context
    data: ?*anyopaque,

    // The actual struct has more fields, but we only need data.
    // libuv guarantees data is at offset 0 for all handle types.
    // Pad to ensure proper allocation size (libuv allocates these)
    _padding: [256 - @sizeOf(?*anyopaque)]u8,
};

/// Generic libuv handle (base type for all handles)
pub const uv_handle_t = opaque {};

/// Timer callback signature as expected by libuv
pub const uv_timer_cb = ?*const fn (handle: *uv_timer_t) callconv(.c) void;

/// Close callback signature
pub const uv_close_cb = ?*const fn (handle: *uv_handle_t) callconv(.c) void;

/// Run modes for uv_run
pub const uv_run_mode = enum(c_int) {
    UV_RUN_DEFAULT = 0,
    UV_RUN_ONCE = 1,
    UV_RUN_NOWAIT = 2,
};

// ============================================================================
// libuv Functions
// ============================================================================

extern "uv" fn uv_loop_init(loop: *uv_loop_t) c_int;
extern "uv" fn uv_loop_close(loop: *uv_loop_t) c_int;
extern "uv" fn uv_run(loop: *uv_loop_t, mode: uv_run_mode) c_int;
extern "uv" fn uv_stop(loop: *uv_loop_t) void;

extern "uv" fn uv_timer_init(loop: *uv_loop_t, handle: *uv_timer_t) c_int;
extern "uv" fn uv_timer_start(handle: *uv_timer_t, cb: uv_timer_cb, timeout: u64, repeat: u64) c_int;
extern "uv" fn uv_timer_stop(handle: *uv_timer_t) c_int;
extern "uv" fn uv_timer_get_due_in(handle: *const uv_timer_t) u64;

extern "uv" fn uv_now(loop: *const uv_loop_t) u64;
extern "uv" fn uv_update_time(loop: *uv_loop_t) void;
extern "uv" fn uv_backend_timeout(loop: *const uv_loop_t) c_int;

extern "uv" fn uv_close(handle: *uv_handle_t, close_cb: uv_close_cb) void;
extern "uv" fn uv_is_closing(handle: *const uv_handle_t) c_int;
extern "uv" fn uv_is_active(handle: *const uv_handle_t) c_int;

extern "uv" fn uv_loop_size() usize;
extern "uv" fn uv_handle_size(handle_type: c_int) usize;

// Handle type constants
pub const UV_TIMER: c_int = 13;

// ============================================================================
// Zig Wrappers
// ============================================================================

/// Initialize a libuv event loop.
/// Returns error if initialization fails.
pub fn loopInit(loop: *uv_loop_t) !void {
    const result = uv_loop_init(loop);
    if (result < 0) {
        return error.LoopInitFailed;
    }
}

/// Close a libuv event loop.
/// All handles must be closed before calling this.
pub fn loopClose(loop: *uv_loop_t) !void {
    const result = uv_loop_close(loop);
    if (result < 0) {
        return error.LoopCloseFailed;
    }
}

/// Run the event loop.
/// Returns the number of active handles/requests.
pub fn run(loop: *uv_loop_t, mode: uv_run_mode) c_int {
    return uv_run(loop, mode);
}

/// Stop the event loop.
pub fn stop(loop: *uv_loop_t) void {
    uv_stop(loop);
}

/// Initialize a timer handle.
pub fn timerInit(loop: *uv_loop_t, handle: *uv_timer_t) !void {
    const result = uv_timer_init(loop, handle);
    if (result < 0) {
        return error.TimerInitFailed;
    }
}

/// Start a timer.
/// timeout: milliseconds until first callback
/// repeat: milliseconds between subsequent callbacks (0 for one-shot)
pub fn timerStart(handle: *uv_timer_t, cb: uv_timer_cb, timeout: u64, repeat: u64) !void {
    const result = uv_timer_start(handle, cb, timeout, repeat);
    if (result < 0) {
        return error.TimerStartFailed;
    }
}

/// Stop a timer.
pub fn timerStop(handle: *uv_timer_t) !void {
    const result = uv_timer_stop(handle);
    if (result < 0) {
        return error.TimerStopFailed;
    }
}

/// Close a handle.
/// The callback is called once the handle is fully closed.
pub fn close(handle: *uv_handle_t, cb: uv_close_cb) void {
    uv_close(handle, cb);
}

/// Check if a handle is closing.
pub fn isClosing(handle: *const uv_handle_t) bool {
    return uv_is_closing(handle) != 0;
}

/// Check if a handle is active.
pub fn isActive(handle: *const uv_handle_t) bool {
    return uv_is_active(handle) != 0;
}

/// Get the size of a uv_loop_t structure.
pub fn getLoopSize() usize {
    return uv_loop_size();
}

/// Get the size of a handle type.
pub fn getHandleSize(handle_type: c_int) usize {
    return uv_handle_size(handle_type);
}

/// Cast a timer handle to a generic handle.
pub fn timerToHandle(timer: *uv_timer_t) *uv_handle_t {
    return @ptrCast(timer);
}

/// Cast a timer handle to a const generic handle.
pub fn timerToHandleConst(timer: *const uv_timer_t) *const uv_handle_t {
    return @ptrCast(timer);
}

/// Get milliseconds until a timer fires.
/// Returns 0 if the timer is not active.
pub fn timerGetDueIn(handle: *const uv_timer_t) u64 {
    return uv_timer_get_due_in(handle);
}

/// Get the current loop time in milliseconds.
/// This is cached - call updateTime() to refresh.
pub fn now(loop: *const uv_loop_t) u64 {
    return uv_now(loop);
}

/// Update the loop's concept of "now".
/// Call this before calculating timeouts if you need accurate timing.
pub fn updateTime(loop: *uv_loop_t) void {
    uv_update_time(loop);
}

/// Get the recommended poll timeout for the loop.
/// Returns -1 if no timeout (infinite wait), 0 for no wait, or positive ms.
pub fn backendTimeout(loop: *const uv_loop_t) c_int {
    return uv_backend_timeout(loop);
}
