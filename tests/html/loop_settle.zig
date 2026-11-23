//! Waiting for a page's asynchronous work in a native test: until the event
//! loop has nothing left to do, never for a fixed short time.
//!
//! `Browser.runEventLoopBlocking(ms)` turns the loop until `ms` of WALL time
//! pass or it has no pending work - a task queued, a fetch in flight, a
//! timer, a worker that may post (event_loop.hasPendingWork). A small `ms`
//! before an assertion about asynchronous work (a script fetch, an
//! import(), a force-async script, the load event its task fires) is a
//! deadline, not a wait: on a quiet host the work beats it, on a loaded or
//! starved one the thread may not be scheduled within it at all, and the
//! assertion reads nothing done (lane mem1, 2026-11-22: edges_svg_script_
//! queue's load test FLAKY in main's gate on a loaded chat2, log empty; red
//! 6 of 10 runs alone on one CPU shared with 8 busy loops. Lessons
//! testing-a-test-that-waits-one-turn-races-a-step-that-went-parallel and
//! testing-starve-a-test-of-cpu-to-reproduce-a-flake-that-needs-a-stalled-
//! host).
//!
//! `settle` waits for the work instead: the bound is only a net for a loop
//! that never goes idle, so a starved host gets the time it needs and a
//! quiet one returns at once.
const browser_mod = @import("browser");

/// The most a settle waits for the loop to go idle: a net for a loop that
/// never does, far past any work a test queues even on a starved host (the
/// launcher's per-test timeout is 300 s).
pub const bound_ms: u64 = 120_000;

/// Turn `browser`'s event loop until it has no pending work - every task
/// queued, and what those tasks queued, has run - `bound_ms` at most.
pub fn settle(browser: *browser_mod.Browser) !void {
    _ = try browser.runEventLoopBlocking(bound_ms);
}
