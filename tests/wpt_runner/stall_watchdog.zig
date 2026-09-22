//! A stall watchdog for the supervisor's child process.
//!
//! The per-file ceiling in `wpt_browser.waitForCompletion` bounds the *wait for
//! `__wpt_complete`* and nothing else. Everything before it - the navigation,
//! the HTML parse, and every script the parser runs - is unbounded, and
//! `fetch()` is synchronous down to `curl_easy_perform`. So a page whose
//! scripts poll in a loop holds the process inside `loadPage` forever and the
//! ceiling is never reached:
//!
//!     loadPageWithOptions -> parseHTMLWithScripting -> runClassicScript
//!       -> PerformCheckpoint -> AsyncFunctionAwaitResolveClosure
//!         -> fetchCallback -> curl_easy_perform -> poll()
//!
//! `common/dispatcher/dispatcher.js` is the common shape - `while(1) { try {
//! await fetch(...) } catch {} }` - and 251 `html/` sources load it. One such
//! file ran 78 minutes against a 10-second ceiling and stalled every test
//! queued behind it.
//!
//! The supervisor cannot see inside the child, but it can see the journal: one
//! record per finished file. A journal that has not grown is a child that has
//! not finished a file. That is the signal this watches, because it needs no
//! cooperation from the code that is stuck.
//!
//! The watchdog is deliberately blunt. It does not try to distinguish a slow
//! file from a hung one - `stall_limit_ms` is set well past the longest legal
//! per-file ceiling so that anything above it is a hang by definition.

const std = @import("std");
const host = @import("host");
const clock = @import("clock");

/// The last time the journal was seen to grow.
///
/// `size` is the byte length rather than a record count so that observing it
/// costs a stat rather than a read of an ever-growing file.
pub const Progress = struct {
    size: u64,
    /// Monotonic milliseconds at which `size` was first seen.
    at_ms: i64,
};

/// Fold a new observation into the progress record.
///
/// A size that changed restarts the clock; a size that did not keeps the
/// original timestamp, which is what makes `at_ms` "how long it has been
/// stuck" rather than "when we last looked".
///
/// A size that went *down* also restarts the clock. That does not happen in
/// normal operation, but a truncated journal is not evidence of a hang and
/// must not be treated as one.
pub fn observe(prev: Progress, size: u64, now_ms: i64) Progress {
    if (size != prev.size) return .{ .size = size, .at_ms = now_ms };
    return prev;
}

/// Has the journal been unchanged for longer than the limit?
///
/// `limit_ms == 0` disables the watchdog: a caller that does not want a child
/// killed must be able to say so without a second flag.
pub fn stalled(p: Progress, now_ms: i64, limit_ms: u64) bool {
    if (limit_ms == 0) return false;
    if (now_ms <= p.at_ms) return false;
    return @as(u64, @intCast(now_ms - p.at_ms)) >= limit_ms;
}

/// Byte length of `path`, or 0 when it does not exist yet.
///
/// A missing journal is indistinguishable from an empty one for this purpose -
/// both mean "no file has finished" - and the first child of a run is spawned
/// before the journal exists.
pub fn journalSize(path: []const u8) u64 {
    const io = host.io();
    const file = host.cwd().openFile(io, path, .{}) catch return 0;
    defer file.close(io);
    const stat = file.stat(io) catch return 0;
    return stat.size;
}

/// How long a child may make no progress before it is killed, in milliseconds.
///
/// The longest legal per-file budget is `config.Timeout.long` at 60s, plus the
/// navigation and load phases ahead of it. Double that: a file legitimately
/// taking over two minutes does not exist in this corpus, and a false kill
/// costs a re-run of one file while a missed hang costs the whole sweep.
pub const default_stall_limit_ms: u64 = 150_000;

/// Watches a journal and SIGKILLs a child that stops adding to it.
///
/// Owned by the supervisor thread that spawned the child: `start` before the
/// blocking wait, `stop` after it returns. `stop` joins, so the thread cannot
/// outlive the pid it holds.
pub const Watchdog = struct {
    journal_path: []const u8,
    child_id: std.posix.pid_t,
    stall_limit_ms: u64,
    /// Set by the owner once the child has been reaped. The thread checks it
    /// every poll, so the window in which it could signal a pid the kernel has
    /// already recycled is one poll interval - and it only signals at all
    /// after `stall_limit_ms` of no progress, which a child that just exited
    /// normally cannot have accumulated.
    done: std.atomic.Value(bool) = .init(false),
    /// Set by the thread when it kills. Read by the owner to tell a hang from
    /// an ordinary crash, which get different journal statuses.
    fired: std.atomic.Value(bool) = .init(false),
    thread: ?std.Thread = null,

    /// How often to stat the journal. Small enough that `stop` returns
    /// promptly, large enough that the stat is free next to the test run.
    const poll_ms: u64 = 1_000;

    pub fn start(self: *Watchdog) !void {
        if (self.stall_limit_ms == 0) return;
        self.thread = try std.Thread.spawn(.{}, loop, .{self});
    }

    /// Stop watching and join. Safe to call when `start` was skipped.
    pub fn stop(self: *Watchdog) void {
        self.done.store(true, .release);
        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    /// True when this watchdog, rather than the test itself, ended the child.
    pub fn killedChild(self: *const Watchdog) bool {
        return self.fired.load(.acquire);
    }

    fn loop(self: *Watchdog) void {
        var progress: Progress = .{
            .size = journalSize(self.journal_path),
            .at_ms = clock.monotonicMillis(),
        };

        while (!self.done.load(.acquire)) {
            clock.sleep(poll_ms * std.time.ns_per_ms);
            if (self.done.load(.acquire)) return;

            progress = observe(progress, journalSize(self.journal_path), clock.monotonicMillis());
            if (!stalled(progress, clock.monotonicMillis(), self.stall_limit_ms)) continue;

            // Order matters: claim the kill before making it, so the owner
            // never reaps a killed child and reads `fired` as false.
            self.fired.store(true, .release);
            std.posix.kill(self.child_id, std.posix.SIG.KILL) catch {};
            return;
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "a journal that grows restarts the stall clock" {
    const start: Progress = .{ .size = 100, .at_ms = 1_000 };

    // Same size, later: the timestamp is the moment it *became* this size, not
    // the moment we looked.
    const same = observe(start, 100, 5_000);
    try std.testing.expectEqual(@as(i64, 1_000), same.at_ms);
    try std.testing.expectEqual(@as(u64, 100), same.size);

    // A record was appended: the clock restarts.
    const grown = observe(same, 260, 5_000);
    try std.testing.expectEqual(@as(i64, 5_000), grown.at_ms);
    try std.testing.expectEqual(@as(u64, 260), grown.size);
}

test "a truncated journal is not a hang" {
    const start: Progress = .{ .size = 4_096, .at_ms = 1_000 };
    const shrunk = observe(start, 0, 9_000);

    // Nothing about a smaller file says the child is stuck, and treating it as
    // a stall would kill a run that merely rotated its journal.
    try std.testing.expectEqual(@as(i64, 9_000), shrunk.at_ms);
    try std.testing.expect(!stalled(shrunk, 9_000, 150_000));
}

test "stalled fires only at the limit" {
    const p: Progress = .{ .size = 100, .at_ms = 1_000 };

    try std.testing.expect(!stalled(p, 1_000, 10_000));
    try std.testing.expect(!stalled(p, 10_999, 10_000));
    // Exactly at the limit counts, so a limit of N means "N ms of silence".
    try std.testing.expect(stalled(p, 11_000, 10_000));
    try std.testing.expect(stalled(p, 99_000, 10_000));
}

test "a zero limit disables the watchdog" {
    const p: Progress = .{ .size = 0, .at_ms = 0 };

    // Every other input says "stalled"; the limit is what must veto it, so a
    // caller can turn the watchdog off without a second flag.
    try std.testing.expect(!stalled(p, 1_000_000, 0));
}

test "a clock that went backwards is not a hang" {
    const p: Progress = .{ .size = 100, .at_ms = 5_000 };

    // clock.monotonicMillis should never do this, but the subtraction below it
    // is unsigned: reading it as an enormous elapsed time would kill a healthy
    // child on the spot.
    try std.testing.expect(!stalled(p, 4_000, 1_000));
    try std.testing.expect(!stalled(p, 5_000, 1_000));
}

test "the default limit is past the longest per-file budget" {
    // config.Timeout.long is 60s, and the navigation and load phases run
    // before that clock starts. Anything at or below the ceiling would make
    // the watchdog a source of false kills rather than a backstop.
    try std.testing.expect(default_stall_limit_ms > 60_000 * 2);
}

test "journalSize reports zero for a file that is not there" {
    // The first child of a run is spawned before any record exists, so this
    // path is taken on every run, not just on error.
    try std.testing.expectEqual(
        @as(u64, 0),
        journalSize("tmp/debug/definitely-not-a-journal-1a2b3c.jsonl"),
    );
}
