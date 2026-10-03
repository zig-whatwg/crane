//! requestIdleCallback's idle periods, between the event loop that starts
//! them, the Window whose idle callbacks run in them, and the IdleDeadline
//! that reports them.
//!
//! HTML 8.1.7.3 step 5: a window event loop with no runnable task starts an
//! idle period for each of its windows (Cooperative Scheduling of Background
//! Tasks, "start an idle period"), with a `computeDeadline` the loop answers:
//! 50 ms from the period's start at most, and no later than the next timer or
//! the next rendering opportunity. Three owners meet here, and none may name
//! another:
//!   - the event loop is the browser layer's (src/browser/event_loop.zig),
//!     which no impl reaches: it installs `Loop`;
//!   - the lists of idle callbacks are the Window's (impls/Window.zig), which
//!     hands its "start an idle period" steps to `requestIdlePeriod`;
//!   - an IdleDeadline is made only by its own impl: it installs `Deadlines`.
//!
//! Times are `clock.monotonicNanos()`.
//!
//! Spec: https://w3c.github.io/requestidlecallback/#start-an-idle-period-algorithm
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model
//!
//! lint-impls: hook for Context, IdleDeadline
const std = @import("std");
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// An idle period, as its event loop started it.
pub const Period = struct {
    /// Which of its loop's idle periods this is (1, 2, ...): the loop tells
    /// the current one from those that have ended.
    id: u64,
    /// The deadline `computeDeadline` gave when the period started. The
    /// period ends then at the latest: work that arrives during it - a timer,
    /// an animation frame - can only bring the deadline forward
    /// (`Loop.deadline` asks again).
    end_ns: i64,
};

/// A window's "start an idle period" steps (steps 2-6): its pending idle
/// callbacks become runnable, and a task to invoke them is queued. `realm` is
/// the window's, BORROWED and possibly retired since it asked: the steps check
/// `hasEngine()` before they reach the window.
pub const StartIdlePeriod = *const fn (realm: runtime.Context, period: Period) void;

/// What the event loop's owner supplies.
pub const Loop = struct {
    /// `realm`'s window has idle callbacks waiting: its event loop runs
    /// `start` when it next starts an idle period, once. Asking again before
    /// then is asking once.
    request: *const fn (realm: runtime.Context, start: StartIdlePeriod) void,
    /// `computeDeadline` now, for `period` of `realm`'s event loop: the
    /// period's end, or the loop's next timer or rendering opportunity when
    /// that comes first.
    deadline: *const fn (realm: runtime.Context, period: Period) i64,
};

/// The get deadline time algorithm an IdleDeadline is made with.
pub const Deadline = union(enum) {
    /// "invoke idle callbacks" step 3.2: the idle period's computeDeadline,
    /// asked each time (Loop.deadline). didTimeout is false.
    period: Period,
    /// "invoke idle callback timeout" step 2.3: an algorithm returning the
    /// time the timeout's task ran (ns), and timeout true.
    timed_out: i64,
};

/// What IdleDeadline supplies.
pub const Deadlines = struct {
    /// A new IdleDeadline in `realm` with `deadline`: the caller's until the
    /// engine wraps it (Instance.releaseIfUnwrapped).
    create: *const fn (realm: runtime.Context, deadline: Deadline) anyerror!*runtime.Instance,
};

// process-wide: function pointers the browser layer installs once at process start (crane.Process), the same for every instance
var loop: ?Loop = null;
// process-wide: function pointers IdleDeadline installs once at process start (crane.Process), the same for every instance
var deadlines: ?Deadlines = null;

/// Called by the browser layer, once, at process start (process_start.zig).
pub fn installLoop(impl: Loop) void {
    process_start.assertInstalling();
    loop = impl;
}

/// Called by IdleDeadline's installHooks, once, at process start.
pub fn installDeadlines(impl: Deadlines) void {
    process_start.assertInstalling();
    deadlines = impl;
}

/// Ask `realm`'s event loop for an idle period. Without an installed loop -
/// a context built for tests - none ever starts, and idle callbacks wait.
pub fn requestIdlePeriod(realm: runtime.Context, start: StartIdlePeriod) void {
    const impl = loop orelse return;
    impl.request(realm, start);
}

/// `period`'s deadline now (ns): its end, brought forward by the loop's next
/// timer or rendering opportunity. Without an installed loop, its end.
pub fn deadline(realm: runtime.Context, period: Period) i64 {
    const impl = loop orelse return period.end_ns;
    return impl.deadline(realm, period);
}

/// A new IdleDeadline in `realm` (see Deadlines.create).
pub fn createDeadline(realm: runtime.Context, value: Deadline) !*runtime.Instance {
    const impl = deadlines orelse return error.NotSupported;
    return impl.create(realm, value);
}

test "without an installed loop no idle period is asked for, and a period's deadline is its end" {
    const saved = loop;
    defer loop = saved;
    loop = null;
    // Never dereferenced: without an implementation nothing reads it.
    var realm: runtime.ContextData = undefined;
    const Never = struct {
        fn start(_: runtime.Context, _: Period) void {
            unreachable;
        }
    };
    requestIdlePeriod(&realm, &Never.start);
    try std.testing.expectEqual(@as(i64, 1234), deadline(&realm, .{ .id = 1, .end_ns = 1234 }));
}

test "without IdleDeadline installed no deadline object is made" {
    const saved = deadlines;
    defer deadlines = saved;
    deadlines = null;
    var realm: runtime.ContextData = undefined;
    try std.testing.expectError(error.NotSupported, createDeadline(&realm, .{ .timed_out = 0 }));
}
