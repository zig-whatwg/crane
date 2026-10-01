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
const builtin = @import("builtin");
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

/// The child's per-run heartbeat: `<journal>.heartbeat`. Caller owns the path.
///
/// A file is `globals x variants` runs, each under its own ceiling (the
/// per-URL timeout wptrunner gives every test URL), and the journal gains a
/// record only when the last run of a file ends. The child appends to the
/// heartbeat as each run starts, so a watchdog that counts it sees a legal
/// many-variant file make progress; a run that hangs still makes none.
pub fn heartbeatPath(allocator: std.mem.Allocator, journal_path: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}.heartbeat", .{journal_path});
}

/// What the supervisor's watchdog watches: the journal's size plus the
/// heartbeat's. Either growing is progress.
pub fn watchedSize(journal_path: []const u8, heartbeat_path: ?[]const u8) u64 {
    const beats = if (heartbeat_path) |p| journalSize(p) else 0;
    return journalSize(journal_path) + beats;
}

/// The child's side of the heartbeat: one byte appended per run, straight to
/// the descriptor (no buffer to flush, nothing to lose to a crash).
///
/// Best effort. A heartbeat that cannot be opened beats nothing: the run goes
/// on, watched by its journal alone as before.
pub const Heartbeat = struct {
    fd: ?std.c.fd_t = null,

    pub fn open(path: []const u8) Heartbeat {
        if (!builtin.link_libc) return .{};
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        if (path.len >= buf.len) return .{};
        @memcpy(buf[0..path.len], path);
        buf[path.len] = 0;
        const flags: std.c.O = .{ .ACCMODE = .WRONLY, .CREAT = true, .APPEND = true };
        const fd = std.c.open(@ptrCast(&buf), flags, @as(std.c.mode_t, 0o644));
        if (fd < 0) return .{};
        return .{ .fd = fd };
    }

    pub fn beat(self: *const Heartbeat) void {
        if (self.fd) |fd| writeAllFd(fd, ".");
    }

    pub fn close(self: *Heartbeat) void {
        if (self.fd) |fd| _ = std.c.close(fd);
        self.fd = null;
    }
};

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
    /// The child's per-run heartbeat (`heartbeatPath`), counted with the
    /// journal; null watches the journal alone.
    heartbeat_path: ?[]const u8 = null,
    child_id: std.posix.pid_t,
    stall_limit_ms: u64,
    /// What a stall does. SIGKILL the child; the tests replace it.
    on_stall: *const fn (*Watchdog) void = killChild,
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
    /// The tests shorten it.
    poll_ms: u64 = 1_000,

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
            .size = watchedSize(self.journal_path, self.heartbeat_path),
            .at_ms = clock.monotonicMillis(),
        };

        while (!self.done.load(.acquire)) {
            clock.sleep(self.poll_ms * std.time.ns_per_ms);
            if (self.done.load(.acquire)) return;

            progress = observe(progress, watchedSize(self.journal_path, self.heartbeat_path), clock.monotonicMillis());
            if (!stalled(progress, clock.monotonicMillis(), self.stall_limit_ms)) continue;

            // Order matters: claim the kill before making it, so the owner
            // never reaps a killed child and reads `fired` as false.
            self.fired.store(true, .release);
            self.on_stall(self);
            return;
        }
    }

    /// The default stall action.
    pub fn killChild(self: *Watchdog) void {
        std.posix.kill(self.child_id, std.posix.SIG.KILL) catch {};
    }
};

/// The exit status of a run its own deadline ended: what `timeout(1)` uses,
/// so a pooled job's wrapper reads it as "timed out", not as a crash.
pub const stall_exit_code: u8 = 124;

/// The in-process deadline of a run that has no supervisor (`wpt_runner
/// <path>`, or a `--journal`/`--baseline` run without `--parallel`).
///
/// A supervised run is bounded by its parent's `Watchdog`; an in-process run
/// had no bound at all. The per-file ceiling covers only the wait for
/// `__wpt_complete`, and synchronous script, a `fetch()` blocked in curl and a
/// teardown under `CRANE_LEAK_TRACES=1` are all outside it - one such run sat
/// 38 minutes at 100% CPU holding a shared runner token.
///
/// A check made by the thread that runs the tests cannot fire while that
/// thread is stuck, so this one runs on a thread of its own and watches a
/// progress counter the owner bumps (`mark`) as each file starts and once
/// more when the last has finished. The limit is the supervisor's: no
/// progress for `stall_limit_ms`. The stuck thread cannot be unwound from
/// here, so the default action ends the process (`endRun`); the owner may
/// replace it to record the file first, as the supervisor does.
pub const SelfWatchdog = struct {
    stall_limit_ms: u64,
    /// How often the thread looks. The tests shorten it.
    poll_ms: u64 = 1_000,
    /// Run on the watchdog thread when the limit passes. It must not take a
    /// lock the stuck thread may hold - not the run's allocator, whose
    /// DebugAllocator mutex is held for the whole of a traced allocation.
    on_stall: *const fn (*SelfWatchdog) void = endRun,
    /// For `on_stall`.
    context: ?*anyopaque = null,

    /// Bumped by every `mark`. Written by the owner, read by the thread.
    progress: std.atomic.Value(u64) = .init(0),
    /// The file in progress, for the stall message and the journal. Written
    /// by the owner before it bumps `progress` (release), so the thread sees a
    /// whole label - and it reads it only after `stall_limit_ms` without a
    /// mark, when the owner is not writing it.
    index: usize = 0,
    label_buf: [512]u8 = undefined,
    label_len: usize = 0,

    done: std.atomic.Value(bool) = .init(false),
    fired: std.atomic.Value(bool) = .init(false),
    thread: ?std.Thread = null,

    pub fn start(self: *SelfWatchdog) !void {
        if (self.stall_limit_ms == 0) return;
        self.thread = try std.Thread.spawn(.{}, loop, .{self});
    }

    /// Stop watching and join. Safe to call when `start` was skipped.
    pub fn stop(self: *SelfWatchdog) void {
        self.done.store(true, .release);
        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    /// The owner made progress: it is starting the file at worklist `index`
    /// (or, after the last file, a phase such as teardown) named `label`.
    pub fn mark(self: *SelfWatchdog, index: usize, label: []const u8) void {
        const n = @min(label.len, self.label_buf.len);
        @memcpy(self.label_buf[0..n], label[0..n]);
        self.label_len = n;
        self.index = index;
        _ = self.progress.fetchAdd(1, .release);
    }

    pub fn currentIndex(self: *const SelfWatchdog) usize {
        return self.index;
    }

    pub fn currentLabel(self: *const SelfWatchdog) []const u8 {
        return self.label_buf[0..self.label_len];
    }

    fn loop(self: *SelfWatchdog) void {
        var progress: Progress = .{
            .size = self.progress.load(.acquire),
            .at_ms = clock.monotonicMillis(),
        };
        while (!self.done.load(.acquire)) {
            clock.sleep(self.poll_ms * std.time.ns_per_ms);
            if (self.done.load(.acquire)) return;

            progress = observe(progress, self.progress.load(.acquire), clock.monotonicMillis());
            if (!stalled(progress, clock.monotonicMillis(), self.stall_limit_ms)) continue;

            self.fired.store(true, .release);
            self.on_stall(self);
            return;
        }
    }
};

/// The default stall action: say which file the run is ending on, straight
/// to stderr (the runner's buffered sink belongs to the stuck thread), and end
/// the process at once with `stall_exit_code`.
///
/// `_exit`, not `exit`: the stuck thread is inside V8 or curl, and `exit`
/// would run atexit handlers and C++ static destructors under it.
pub fn endRun(w: *SelfWatchdog) void {
    var buf: [768]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "\n!!! wpt_runner: no progress for {d}ms in [{d}] {s}; ending the run (exit {d}). --stall-limit-ms=0 disables this.\n", .{
        w.stall_limit_ms, w.currentIndex(), w.currentLabel(), stall_exit_code,
    }) catch buf[0..0];
    writeStderr(msg);
    if (builtin.link_libc) std.c._exit(stall_exit_code);
    std.process.exit(stall_exit_code);
}

/// write(2) to fd 2 until done or it fails. No buffer, no lock.
pub fn writeStderr(bytes: []const u8) void {
    writeAllFd(2, bytes);
}

/// write(2) `bytes` to `fd` until done or it fails. No buffer, no lock: for
/// the watchdog thread, which must not wait on anything the stuck thread holds.
pub fn writeAllFd(fd: std.c.fd_t, bytes: []const u8) void {
    var rest = bytes;
    while (rest.len > 0) {
        const n = std.c.write(fd, rest.ptr, rest.len);
        if (n <= 0) return;
        rest = rest[@intCast(n)..];
    }
}

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

// ----------------------------------------------------------------------------
// The in-process deadline (SelfWatchdog)
// ----------------------------------------------------------------------------

/// What a test's stall action saw, written from the watchdog thread.
const SeenStall = struct {
    calls: std.atomic.Value(u32) = .init(0),
    index: usize = 0,
    label_buf: [64]u8 = undefined,
    label_len: usize = 0,

    fn action(w: *SelfWatchdog) void {
        const self: *SeenStall = @ptrCast(@alignCast(w.context.?));
        self.index = w.currentIndex();
        const l = w.currentLabel();
        @memcpy(self.label_buf[0..l.len], l);
        self.label_len = l.len;
        _ = self.calls.fetchAdd(1, .release);
    }
};

test "a run with no supervisor ends itself when no file finishes within the limit" {
    var seen: SeenStall = .{};
    var w: SelfWatchdog = .{
        .stall_limit_ms = 50,
        .poll_ms = 5,
        .on_stall = SeenStall.action,
        .context = &seen,
    };
    try w.start();
    w.mark(7, "dom/stuck-in-script.html");
    // The owner never marks again - it is inside synchronous script. Nothing
    // the owner does can end it; the deadline has to come from outside.
    clock.sleep(400 * std.time.ns_per_ms);
    w.stop();

    try std.testing.expectEqual(@as(u32, 1), seen.calls.load(.acquire));
    try std.testing.expect(w.fired.load(.acquire));
    // The action is told which file it is ending, for the message and the
    // journal's TIMEOUT record.
    try std.testing.expectEqual(@as(usize, 7), seen.index);
    try std.testing.expectEqualStrings("dom/stuck-in-script.html", seen.label_buf[0..seen.label_len]);
}

test "a run that keeps finishing files is never ended" {
    var seen: SeenStall = .{};
    var w: SelfWatchdog = .{
        .stall_limit_ms = 1_000,
        .poll_ms = 5,
        .on_stall = SeenStall.action,
        .context = &seen,
    };
    try w.start();
    // 150 files of 10 ms: the run lasts longer than the limit, and no single
    // file comes near it. The limit is per file, not per run.
    var i: usize = 0;
    while (i < 150) : (i += 1) {
        w.mark(i, "fast.html");
        clock.sleep(10 * std.time.ns_per_ms);
    }
    w.stop();
    try std.testing.expectEqual(@as(u32, 0), seen.calls.load(.acquire));
    try std.testing.expect(!w.fired.load(.acquire));
}

test "a zero limit disables the in-process deadline" {
    var seen: SeenStall = .{};
    var w: SelfWatchdog = .{ .stall_limit_ms = 0, .poll_ms = 1, .on_stall = SeenStall.action, .context = &seen };
    try w.start();
    try std.testing.expect(w.thread == null);
    clock.sleep(20 * std.time.ns_per_ms);
    w.stop();
    try std.testing.expectEqual(@as(u32, 0), seen.calls.load(.acquire));
}

test "the in-process deadline's default action ends the process with the timeout exit code" {
    // The default is pinned: a run that bounds itself must END, not log and
    // carry on - the stuck thread cannot be unwound, so anything short of
    // ending the process leaves it holding its runner token.
    const w: SelfWatchdog = .{ .stall_limit_ms = default_stall_limit_ms };
    try std.testing.expect(w.on_stall == &endRun);
    try std.testing.expectEqual(@as(u8, 124), stall_exit_code);
    // The same budget the supervisor gives a child.
    try std.testing.expectEqual(default_stall_limit_ms, w.stall_limit_ms);
}

test "a label longer than the slot is truncated, not overflowed" {
    var w: SelfWatchdog = .{ .stall_limit_ms = 0 };
    const long = "a/" ** 400;
    w.mark(3, long);
    try std.testing.expectEqual(@as(usize, 3), w.currentIndex());
    try std.testing.expectEqual(w.label_buf.len, w.currentLabel().len);
    try std.testing.expectEqualStrings(long[0..w.label_buf.len], w.currentLabel());
}

// ----------------------------------------------------------------------------
// The per-run heartbeat
// ----------------------------------------------------------------------------

test "the heartbeat lives beside the journal" {
    const allocator = std.testing.allocator;
    const p = try heartbeatPath(allocator, "out/chunks/aaa/journal.shard0.jsonl");
    defer allocator.free(p);
    // Not *.jsonl: the sweep folds journal.shard*.jsonl into its journal, and
    // the progress page reads *.jsonl.
    try std.testing.expectEqualStrings("out/chunks/aaa/journal.shard0.jsonl.heartbeat", p);
}

test "a run that starts between journal records is progress" {
    // A file is `globals x variants` runs, each with its own ceiling - the
    // per-URL timeout wptrunner gives every test URL. Four 60 s variants are a
    // legal 240 s with no journal record until the last ends, and the
    // supervisor killed such files at 150 s and lost every result in them
    // (15 of the full corpus's 19 stall kills, 2026-10-01). The child beats
    // once per run; the watchdog counts the beats with the journal.
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(dir_path);
    const journal = try std.fs.path.join(allocator, &.{ dir_path, "journal.jsonl" });
    defer allocator.free(journal);
    const beat_path = try heartbeatPath(allocator, journal);
    defer allocator.free(beat_path);

    try std.testing.expectEqual(@as(u64, 0), watchedSize(journal, beat_path));

    var beat = Heartbeat.open(beat_path);
    defer beat.close();
    beat.beat();
    const after_one = watchedSize(journal, beat_path);
    try std.testing.expect(after_one > 0);
    beat.beat();
    try std.testing.expect(watchedSize(journal, beat_path) > after_one);

    // And the clock restarts on it, as on a journal record.
    const before: Progress = .{ .size = after_one, .at_ms = 1_000 };
    const now = observe(before, watchedSize(journal, beat_path), 140_000);
    try std.testing.expectEqual(@as(i64, 140_000), now.at_ms);
}

test "a heartbeat that cannot be opened beats nothing and fails nothing" {
    // The watchdog is a backstop: a missing directory must not stop a run.
    var beat = Heartbeat.open("tmp/debug/no-such-dir-9f8e7d/journal.jsonl.heartbeat");
    defer beat.close();
    beat.beat();
    try std.testing.expect(beat.fd == null);
}

/// What a test's supervisor-watchdog action saw.
const SeenKill = struct {
    var calls: std.atomic.Value(u32) = .init(0);
    fn action(_: *Watchdog) void {
        _ = calls.fetchAdd(1, .release);
    }
};

test "a four-variant file whose runs each fit their ceiling is not killed; a stalled run is" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(dir_path);
    const journal = try std.fs.path.join(allocator, &.{ dir_path, "journal.shard0.jsonl" });
    defer allocator.free(journal);
    const beat_path = try heartbeatPath(allocator, journal);
    defer allocator.free(beat_path);

    // Scaled down: a 250 ms limit stands for 150 s, a 100 ms run for a 60 s
    // variant. Four runs are 400 ms with no journal record - past the limit
    // as a whole, inside it run by run (with room for a loaded machine's
    // late wake-ups).
    SeenKill.calls.store(0, .release);
    var w: Watchdog = .{
        .journal_path = journal,
        .heartbeat_path = beat_path,
        .child_id = 0,
        .stall_limit_ms = 250,
        .poll_ms = 5,
        .on_stall = SeenKill.action,
    };
    try w.start();
    var beat = Heartbeat.open(beat_path);
    defer beat.close();
    try std.testing.expect(beat.fd != null);
    var run: usize = 0;
    while (run < 4) : (run += 1) {
        beat.beat();
        clock.sleep(100 * std.time.ns_per_ms);
    }
    try std.testing.expectEqual(@as(u32, 0), SeenKill.calls.load(.acquire));
    try std.testing.expect(!w.killedChild());

    // The fifth run hangs: no beat, no record. The limit still ends it.
    clock.sleep(1_000 * std.time.ns_per_ms);
    w.stop();
    try std.testing.expectEqual(@as(u32, 1), SeenKill.calls.load(.acquire));
    try std.testing.expect(w.killedChild());
}

test "without a heartbeat the same four runs are killed (the defect this fixes)" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realPathFileAlloc(std.testing.io, ".", allocator);
    defer allocator.free(dir_path);
    const journal = try std.fs.path.join(allocator, &.{ dir_path, "journal.shard0.jsonl" });
    defer allocator.free(journal);

    SeenKill.calls.store(0, .release);
    var w: Watchdog = .{
        .journal_path = journal,
        .child_id = 0,
        .stall_limit_ms = 250,
        .poll_ms = 5,
        .on_stall = SeenKill.action,
    };
    try w.start();
    clock.sleep(400 * std.time.ns_per_ms);
    w.stop();
    try std.testing.expectEqual(@as(u32, 1), SeenKill.calls.load(.acquire));
}
