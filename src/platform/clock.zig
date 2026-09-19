//! Process clocks.
//!
//! Zig 0.16 removed `std.time.milliTimestamp`, `nanoTimestamp`, `timestamp`,
//! `sleep`, `Timer` and `Instant`; `std/time.zig` is now 35 lines of unit
//! constants and `epoch`. The replacements live on `std.Io`, which means an
//! `Io` value in scope at every call site.
//!
//! Crane has 203 of those call sites, and most are in leaf spec code - cookie
//! expiry, storage quota, service-worker TTL - reached from JS bindings and from
//! C-ABI callbacks that cannot take an extra parameter. Threading an `Io`
//! through all of them would couple the whole codebase to the Io architecture
//! before that architecture is decided.
//!
//! So this module goes under them instead. It is libc, which Crane already links
//! unconditionally (V8, curl and libuv all require it), and it needs no `Io`.
//! Switching the bodies to `std.Io.Timestamp` later is a one-file change.
//!
//! ## Pick the right clock
//!
//! `monotonicNanos` never goes backwards and is unaffected by NTP steps or the
//! user changing the system clock. Use it for durations, timeouts, deadlines,
//! benchmarks and `performance.now()`.
//!
//! `wall*` is civil time. It jumps. Use it only when the value is shown to a
//! user or crosses a spec boundary that defines it as Unix time - `Date.now()`,
//! cookie `Expires`, HTTP `Date`.
//!
//! Using wall time for a deadline is a live bug class: an NTP step backwards
//! makes a loop spin, and a step forwards fires every pending timer at once.

const std = @import("std");
const builtin = @import("builtin");

/// Nanoseconds since an arbitrary, fixed origin. Monotonic: it never decreases
/// and is immune to system clock adjustments. Compare two readings; the absolute
/// value is meaningless on its own.
pub fn monotonicNanos() i128 {
    if (builtin.os.tag == .windows) {
        // QPC is the monotonic source on Windows; its origin is boot.
        const freq = std.os.windows.QueryPerformanceFrequency();
        const ctr = std.os.windows.QueryPerformanceCounter();
        return @divFloor(@as(i128, ctr) * std.time.ns_per_s, @as(i128, freq));
    }
    var ts: std.c.timespec = undefined;
    // CLOCK.MONOTONIC is POSIX and present on Linux, Darwin and the BSDs.
    // A failure here means the kernel does not implement a clock POSIX requires,
    // so there is no sensible fallback and no caller could act on the error.
    _ = std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &ts);
    return @as(i128, ts.sec) * std.time.ns_per_s + @as(i128, ts.nsec);
}

/// Milliseconds from the monotonic clock. Use for durations and ages, and for any
/// stored instant that will later be subtracted from another reading - mixing a
/// stored wall instant with a monotonic `now` (or vice versa) yields garbage the
/// first time the system clock moves.
pub fn monotonicMillis() i64 {
    return @intCast(@divFloor(monotonicNanos(), std.time.ns_per_ms));
}

/// Nanoseconds since the Unix epoch. Wall clock - can jump forwards or backwards.
pub fn wallNanos() i128 {
    if (builtin.os.tag == .windows) {
        return std.os.windows.teb().ProcessEnvironmentBlock.Reserved9[0];
    }
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.REALTIME, &ts);
    return @as(i128, ts.sec) * std.time.ns_per_s + @as(i128, ts.nsec);
}

/// Milliseconds since the Unix epoch. The direct replacement for
/// `std.time.milliTimestamp` (109 call sites).
pub fn wallMillis() i64 {
    return @intCast(@divFloor(wallNanos(), std.time.ns_per_ms));
}

/// Seconds since the Unix epoch. Replaces `std.time.timestamp` (39 call sites).
pub fn wallSeconds() i64 {
    return @intCast(@divFloor(wallNanos(), std.time.ns_per_s));
}

/// Block the calling thread for at least `nanoseconds`.
///
/// Replaces `std.time.sleep`. Restarts on EINTR so a signal cannot cut the sleep
/// short - `Io.Threaded` installs SIGIO and SIGPIPE handlers, and V8 installs its
/// own, so spurious wakeups are expected in this process rather than theoretical.
pub fn sleep(nanoseconds: u64) void {
    if (builtin.os.tag == .windows) {
        std.os.windows.kernel32.Sleep(@intCast(nanoseconds / std.time.ns_per_ms));
        return;
    }
    var req: std.c.timespec = .{
        .sec = @intCast(nanoseconds / std.time.ns_per_s),
        .nsec = @intCast(nanoseconds % std.time.ns_per_s),
    };
    var rem: std.c.timespec = undefined;
    while (std.c.nanosleep(&req, &rem) == -1) {
        if (std.c._errno().* != @intFromEnum(std.c.E.INTR)) return;
        req = rem;
    }
}

/// Elapsed-time measurement. Replaces `std.time.Timer` (4 call sites).
///
/// Always monotonic, unlike the code this replaces: `src/hr_time/clock.zig`
/// asserted that `std.time.nanoTimestamp()` "provides monotonic time", which was
/// never true - it is the wall clock.
pub const Timer = struct {
    start_ns: i128,

    pub fn start() Timer {
        return .{ .start_ns = monotonicNanos() };
    }

    /// Nanoseconds since `start` or the last `lap`.
    pub fn read(self: *const Timer) u64 {
        const d = monotonicNanos() - self.start_ns;
        return if (d < 0) 0 else @intCast(d);
    }

    /// `read`, then reset the origin to now.
    pub fn lap(self: *Timer) u64 {
        const now = monotonicNanos();
        const d = now - self.start_ns;
        self.start_ns = now;
        return if (d < 0) 0 else @intCast(d);
    }

    pub fn reset(self: *Timer) void {
        self.start_ns = monotonicNanos();
    }
};

test "monotonic never goes backwards" {
    var prev = monotonicNanos();
    for (0..1000) |_| {
        const now = monotonicNanos();
        try std.testing.expect(now >= prev);
        prev = now;
    }
}

test "wall clock is near the Unix epoch, monotonic is not required to be" {
    // Sanity that we read the realtime clock and not something else: any plausible
    // run of this code is after 2020-01-01 and before 2100-01-01.
    const s = wallSeconds();
    try std.testing.expect(s > 1_577_836_800);
    try std.testing.expect(s < 4_102_444_800);
}

test "wallMillis and wallSeconds agree" {
    const ms = wallMillis();
    const s = wallSeconds();
    try std.testing.expect(@divFloor(ms, 1000) == s or @divFloor(ms, 1000) == s - 1);
}

test "Timer measures a real interval" {
    var t: Timer = .start();
    sleep(2 * std.time.ns_per_ms);
    const elapsed = t.read();
    try std.testing.expect(elapsed >= std.time.ns_per_ms);
    // Generous upper bound: this runs on loaded CI machines.
    try std.testing.expect(elapsed < 2 * std.time.ns_per_s);
}

test "Timer.lap resets the origin" {
    var t: Timer = .start();
    sleep(std.time.ns_per_ms);
    const first = t.lap();
    const second = t.read();
    try std.testing.expect(first >= second);
}
