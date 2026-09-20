//! Isolate ownership checking - Phase 5 groundwork.
//!
//! Phase 5's exit criterion needs `Agent.assertOwned` compiled in at every
//! isolate-taking FFI call. Before that can be written, one question has to be
//! answered with evidence rather than assumption: **does Crane already keep each
//! isolate confined to one thread, and entered while it is used?**
//!
//! Plan M12 says it does not - `Isolate::Enter` is scoped today, not permanent
//! (snapshot_loader.zig enters at :164/:254 and EXITS at :168/:273/:434), and
//! worker_v8_context.zig "enters on whatever thread calls it". Workers really do
//! spawn threads (worker_threading.zig:406). If the invariant is already violated
//! in ordinary runs, converting Enter from scoped to permanent would not be a
//! lifetime change, it would be a correctness regression - V8 permits at most one
//! thread inside an isolate at a time.
//!
//! So this is the measuring instrument, not the enforcement. It REPORTS rather
//! than panics, so a full WPT run answers the question without taking the suite
//! down. Once the reports come back empty for a workload, `mode` can be flipped to
//! `.panic` and the same calls become the assertion Phase 5 actually wants.
//!
//! ## STATUS: the mechanism is in, the MEASUREMENT IS NOT YET WORKING
//!
//! Running html/webappapis/timers/ with three sites instrumented produced zero
//! reports - but that number is meaningless, because a deliberately bogus isolate
//! injected at one of those sites produced zero reports too. The log line never
//! reaches the captured output under tests/wpt_runner, even though the format
//! strings are demonstrably compiled into the binary and the instrumented code
//! runs. The runner installs its own std_options.logFn and its own stderr writer
//! (main.zig:75 and the stderr_writer setup), and the warning is being lost
//! somewhere in there.
//!
//! So do NOT read "no violations" as "the invariant holds". Before trusting any
//! result from this, make the self-test visible first: inject
//! `assertOwned(@ptrFromInt(0x1000), "SELFTEST")` at an instrumented site and
//! confirm it appears. Surfacing `violations()` through the runner's own summary,
//! rather than through the log, is probably the more reliable route.
//!
//! ## Why V8's own notion of "current" is the right oracle
//!
//! `Isolate::GetCurrent()` is thread-local: it returns the isolate entered on the
//! CALLING thread. Comparing it against the isolate a caller is about to use
//! therefore catches both failure modes at once - using an isolate that was never
//! entered on this thread, and using one isolate while another is entered. No
//! separate bookkeeping is needed, and none can drift out of date.

const std = @import("std");
const builtin = @import("builtin");
const ffi = @import("ffi.zig");

const log = std.log.scoped(.isolate_ownership);

/// What a violation does.
pub const Mode = enum {
    /// Compiled out entirely.
    off,
    /// Log and continue. The default while the invariant is being measured.
    report,
    /// Panic. Switch to this once a workload reports clean.
    panic,
};

/// Checking is confined to safe builds: the comparison is cheap, but it is
/// diagnostic, and ReleaseFast should not pay for it.
pub const mode: Mode = switch (builtin.mode) {
    .Debug, .ReleaseSafe => .report,
    .ReleaseFast, .ReleaseSmall => .off,
};

/// How many violations have been seen, so a run can be summarised rather than
/// read line by line. Not atomic: a violation means threads are already being
/// mixed, and a precise count is not what the number is for.
var violation_count: usize = 0;

pub fn violations() usize {
    return violation_count;
}

pub fn resetViolations() void {
    violation_count = 0;
}

/// Assert that `isolate` is the one entered on this thread.
///
/// `site` names the caller, since the whole value of a report is knowing which
/// call site broke the invariant.
pub inline fn assertOwned(isolate: *ffi.Isolate, comptime site: []const u8) void {
    if (comptime mode == .off) return;

    const current = ffi.v8_Isolate_GetCurrent();
    if (current == isolate) return;

    violation_count += 1;

    if (comptime mode == .panic) {
        std.debug.panic(
            "isolate ownership violated at {s}: using {*} while {?*} is entered on this thread",
            .{ site, isolate, current },
        );
    }

    log.warn(
        "ownership violation at {s}: using isolate {*}, but {?*} is entered on this thread" ++
            " (null means NO isolate is entered here)",
        .{ site, isolate, current },
    );
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "mode is diagnostic in safe builds and absent from fast ones" {
    // The point of the switch is that ReleaseFast pays nothing. If someone makes
    // checking unconditional, this fails rather than silently costing throughput
    // on the shipped build.
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => try testing.expect(mode != .off),
        .ReleaseFast, .ReleaseSmall => try testing.expectEqual(Mode.off, mode),
    }
}

test "the counter starts clean and resets" {
    resetViolations();
    try testing.expectEqual(@as(usize, 0), violations());
}

test "default mode reports rather than panics" {
    // Deliberate: this lands while the invariant is still being MEASURED. A panic
    // default would take down the WPT suite on the first violation and destroy the
    // very data the instrument exists to collect.
    if (mode != .off) {
        try testing.expectEqual(Mode.report, mode);
    }
}
