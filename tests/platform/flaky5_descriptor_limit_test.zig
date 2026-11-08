//! The process's soft file-descriptor limit after the platform starts
//! (platform.initializePlatform, docs/platform-protocol.md 6.1, which
//! crane.Process.init calls): raised to 8192, or to the hard limit when that
//! is lower; never lowered, and the hard limit never touched.
//!
//! Browsers do the same at start: Chromium's
//! BrowserMainLoop::EarlyInitialization calls base::IncreaseFdLimitTo(8192)
//! ("the default limit on Apple is low (256), so bump it up"), and Gecko's
//! XRE_mainInit calls mozilla::startup::IncreaseDescriptorLimits.
//!
//! Lane flaky5: on macOS the soft limit a process inherits is 256 (the pool
//! hosts' `ulimit -n`), and Crane never raised it. A page's connections hold
//! descriptors (each WebSocket a curl multi handle's wakeup pipe and a
//! socket), and mbedTLS on macOS opens /dev/urandom to seed each TLS
//! connection, so a burst of sockets left a wss:// handshake without the one
//! descriptor it needed: websockets/Create-blocked-port.any.js ?wss "Basic
//! check" failed "CTR_DRBG - The entropy source failed".
//!
//! Each test sets the soft limit it starts from and puts the process's back
//! (tests/AGENTS.md: a test leaves the process as it found it).

const std = @import("std");
const platform = @import("platform");
const testing = std.testing;

/// The soft limit the platform's start asks for (Chromium's number).
const wanted: std.c.rlim_t = 8192;

fn current() !std.c.rlimit {
    var limits: std.c.rlimit = undefined;
    if (std.c.getrlimit(.NOFILE, &limits) != 0) return error.GetrlimitFailed;
    return limits;
}

fn setSoft(soft: std.c.rlim_t) !void {
    var limits = try current();
    limits.cur = soft;
    if (std.c.setrlimit(.NOFILE, &limits) != 0) return error.SetrlimitFailed;
}

/// What the start must leave: `wanted`, or the hard limit below it.
fn expectedSoft(hard: std.c.rlim_t) std.c.rlim_t {
    return if (hard != std.c.RLIM.INFINITY and hard < wanted) hard else wanted;
}

test "platform start: a soft descriptor limit of 256 is raised to 8192, or to the hard limit below it" {
    const before = try current();
    defer setSoft(before.cur) catch {};
    // macOS's default soft limit, which a process started from a shell or
    // launchd inherits.
    if (before.max != std.c.RLIM.INFINITY and before.max < 256) return error.SkipZigTest;
    try setSoft(256);

    try platform.initializePlatform(&.{});

    const after = try current();
    try testing.expectEqual(expectedSoft(before.max), after.cur);
    // The hard limit is the user's: never raised, never lowered.
    try testing.expectEqual(before.max, after.max);
}

test "platform start: a soft descriptor limit above 8192 is kept, never lowered" {
    const before = try current();
    defer setSoft(before.cur) catch {};
    // 10000: above Chromium's 8192 and below macOS's OPEN_MAX (10240), which
    // a soft limit may not pass there.
    const high: std.c.rlim_t = 10000;
    if (before.max != std.c.RLIM.INFINITY and before.max < high) return error.SkipZigTest;
    try setSoft(high);

    try platform.initializePlatform(&.{});

    const after = try current();
    try testing.expectEqual(high, after.cur);
    try testing.expectEqual(before.max, after.max);
}
