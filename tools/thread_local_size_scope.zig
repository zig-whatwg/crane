//! Which test executables the thread-local block check holds to the budget
//! (tools/thread_local_size.zig against tools/thread_local_size_budget.txt;
//! build.zig hangs the check off each suite's own run). std-only, so that
//! build.zig imports it and the tool's tests pin it.
//!
//! The budget is production's thread-local layout: a test executable is held
//! to it because it carries that layout (lane tpf, 2026-11-22: a larger block
//! in a test executable made threads production starts with a small stack
//! fail to start there). One built with -Dsanitize-thread does not carry it:
//! ThreadSanitizer instruments it and links its runtime, whose own
//! thread-local state - `__tsan::cur_thread_placeholder`, 1,856 bytes of the
//! 1,992-byte block every instrumented test executable had on server1 (lane
//! flk4, 2026-11-22) - is in every thread's block. Held to the budget, every
//! suite of `zig build test -Dsanitize-thread` failed its check, and with it
//! the documented single-file ThreadSanitizer route. The plain build checks
//! the same executables, uninstrumented, against the budget.

const std = @import("std");

/// What a build's test executables are built with, as the check asks it.
pub const TestBuild = struct {
    /// -Dsanitize-thread: every test executable is instrumented by
    /// ThreadSanitizer and links its runtime.
    sanitize_thread: bool,
};

/// Whether `build`'s test executables are held to the thread-local budget:
/// a plain build's are; a ThreadSanitizer build's are exempt, carrying the
/// sanitizer runtime's thread-local block rather than production's.
pub fn checksTestExecutables(build: TestBuild) bool {
    return !build.sanitize_thread;
}

test "a plain test build is held to the thread-local budget, and a ThreadSanitizer build is exempt" {
    try std.testing.expect(checksTestExecutables(.{ .sanitize_thread = false }));
    try std.testing.expect(!checksTestExecutables(.{ .sanitize_thread = true }));
}
