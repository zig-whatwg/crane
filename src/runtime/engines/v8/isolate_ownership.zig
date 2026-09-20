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
//! ## STATUS: validated, and the invariant HOLDS at the instrumented sites
//!
//! Result: zero violations across html/webappapis/timers/ - 20 runs, worker
//! variants included - at both timer handlers and the microtask callback.
//!
//! That zero is only worth reading because the instrument was PROVEN to report
//! first. An earlier identical-looking zero was worthless: a deliberately bogus
//! isolate injected at the same site also produced nothing, because the test used
//! (negative-settimeout.any.js) never reaches v8TimerHandler at all. Nothing fired
//! because nothing ran.
//!
//! Validation procedure, which any future measurement here MUST repeat:
//!   1. inject `assertOwned(@ptrFromInt(0x1000), "SELFTEST")` beside a real call,
//!   2. run a test KNOWN to execute that code path - for the timer handlers,
//!      timer-nesting-not-inherited-in-microtask.html, since the Phase 6 clamp
//!      work demonstrably changed its result,
//!   3. confirm SELFTEST appears at the level you intend to use. It was confirmed
//!      separately at `err` and at `warn`; do not assume one implies the other,
//!   4. only then remove the self-test and trust the number.
//!
//! What the result does and does not license. It is evidence that these three
//! callback entry points - the places most likely to break confinement, since
//! they enter V8 from the event loop rather than from JS - run with the right
//! isolate entered. It is NOT coverage of the 69 isolate-taking ffi.zig functions
//! Phase 5 ultimately wants, and it says nothing about paths this workload does
//! not exercise.
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

/// How many checks RAN.
///
/// This exists because "0 violations" is worthless on its own: a zero from an
/// instrument that never executed looks exactly like a zero that means the
/// invariant holds. That mistake was made twice in one session - once by
/// validating against a test that never reached the instrumented code, once by
/// placing an assertion before the Enter it was meant to check.
///
/// Reporting checks alongside violations makes the distinction visible without
/// anyone having to remember to inject a self-test: `0/0` is "measured nothing",
/// `0/5183` is "measured clean".
var check_count: usize = 0;

pub fn violations() usize {
    return violation_count;
}

pub fn checks() usize {
    return check_count;
}

pub fn resetViolations() void {
    violation_count = 0;
    check_count = 0;
}

/// Assert that `isolate` is the one entered on this thread.
///
/// `site` names the caller, since the whole value of a report is knowing which
/// call site broke the invariant.
pub inline fn assertOwned(isolate: *ffi.Isolate, comptime site: []const u8) void {
    if (comptime mode == .off) return;

    check_count += 1;

    const current = ffi.v8_Isolate_GetCurrent();
    if (current == isolate) return;

    violation_count += 1;

    if (comptime mode == .panic) {
        std.debug.panic(
            "isolate ownership violated at {s}: using {*} while {?*} is entered on this thread",
            .{ site, isolate, current },
        );
    }

    log.warn("unowned isolate at {s}", .{site});
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

test "both counters start clean and reset together" {
    resetViolations();
    try testing.expectEqual(@as(usize, 0), violations());
    // checks() must reset too: a stale check count would make a fresh run look
    // measured when it was not, which is the exact failure this counter exists
    // to prevent.
    try testing.expectEqual(@as(usize, 0), checks());
}

test "default mode reports rather than panics" {
    // Deliberate: this lands while the invariant is still being MEASURED. A panic
    // default would take down the WPT suite on the first violation and destroy the
    // very data the instrument exists to collect.
    if (mode != .off) {
        try testing.expectEqual(Mode.report, mode);
    }
}
