//! The shared work queue of a supervised run (`--parallel=N`, `--supervise`).
//!
//! The runners of a supervised run used to get static shards: each child a
//! PRIVATE worklist, a round-robin slice of the run's (`selection.shardIndices`,
//! about 40 files of a 200-file sweep chunk), so the run ended when its slowest
//! shard did. On Crane's full worklist one 60 s timeout held its chunk while
//! the other runners finished in 10-20 s: 905 s of a 2,353 s sweep were that
//! barrier (lane chromeref2, 2026-11-04, against Chrome 157 under wptrunner,
//! whose processes stayed 93% busy). Here every runner CLAIMS its next file
//! from one queue, so a runner is idle only when the queue is empty.
//!
//! wptrunner does the same: `TestQueueBuilder.make_queue` (tools/wptrunner/
//! wptrunner/testloader.py) puts every test group on ONE `queue.SimpleQueue`,
//! and each `TestRunnerManager` thread (testrunner.py) takes its next group
//! with `TestSource.next_group` -> `test_queue.get()` when its current group is
//! empty; a crashed browser is restarted by its manager, which goes on
//! taking from the same queue. Its queue lives in the supervising process
//! because its managers are threads there that hand each test to the browser
//! process as a message.
//!
//! Crane's queue is a CLAIM FILE UNDER A LOCK, not a message, because a
//! Crane child is a whole runner that executes the files itself, and:
//! - the claim has to outlive the child. When a child dies, its supervisor
//!   must know which file it was running; the static loop got that from "the
//!   first index nobody journalled" in the child's private worklist. A
//!   message held in a pipe dies with the process; a claim on disk names the
//!   file, its runner, its child (spawn number) and its pid afterwards.
//! - flock(2) is already how runners on a host coordinate (file_lock.zig's
//!   per-file lock, wpt_server's SpawnLock), and the kernel releases it when
//!   its holder dies, so a child killed while claiming blocks nobody.
//! - the children's stdio is the run's log; a message channel would need
//!   descriptors std.process.spawn does not pass, and a reader per child in
//!   the supervisor.
//! - the file is also the record of which process ran which files in which
//!   order - what a shard-prefix replay needs (docs/lessons/
//!   testing-a-difference-that-appears-with-new-sharding-replay-the-shard-prefix.md).
//!
//! THE QUEUE FILE (`<output>/queue.txt`) is one fixed-width line per file to
//! run, in run order: `IIIIIIIII S RRR NNNNNN PPPPPPPPPP` - the worklist
//! index, the state (`-` unclaimed, `C` claimed), and the claimer's runner,
//! spawn number and pid. A claim takes the file lock, finds the first
//! unclaimed entry (claims are a prefix of the file, so a binary search over
//! the state bytes), writes the claimer's fields and THEN the state byte, and
//! unlocks. A claimer killed between the two writes leaves the entry
//! unclaimed, and the next claimer takes it.
//!
//! THE SUPERVISOR (`run`) writes the queue, runs one thread per runner, each
//! of which keeps a child going while the queue has unclaimed files, and
//! after each child ends journals whatever that child claimed and did not
//! journal: CRASH for a crash, TIMEOUT for a child the stall watchdog killed -
//! the records the static loop wrote. A child that ends between files blames
//! no file. Every runner journals into its own journal (journal.shard<i>.jsonl,
//! the names the static shards had, which crane-measure and the stream
//! collectors know), under GLOBAL worklist indices, and `merge` folds them
//! into the run's journal in worklist order, checking that every file is
//! there exactly once. A file queued but never journalled - its claim
//! unreadable, its runner given up - runs again in a second round, and is
//! journalled ERROR "not run" if no runner journals it then either.
//!
//! STOP AND RESUME: a child checks `--stop-file` before each claim and ends
//! cleanly when it exists, so a run stops within one file's time and leaves
//! the rest unclaimed; the supervisor returns `.stopped`. A run started with
//! `resume_run` over the same worklist keeps what is journalled and queues the
//! rest; over a different worklist it starts afresh.

const std = @import("std");
const host = @import("host");
const journal = @import("journal.zig");
const selection = @import("selection.zig");
const stall_watchdog = @import("stall_watchdog.zig");
const Allocator = std.mem.Allocator;

// ============================================================================
// The queue file
// ============================================================================

/// One queue entry: `{index:9} {state} {runner:3} {spawn:6} {pid:10}\n`.
pub const entry_len: usize = 34;
const state_at: usize = 10;
const fields_at: usize = 12;
/// `{runner:3} {spawn:6} {pid:10}`.
const fields_len: usize = 21;
const unclaimed: u8 = '-';
const claimed: u8 = 'C';

/// Runners a queue can name: the runner field's width.
pub const max_runners: usize = 1000;

pub const Claim = struct {
    runner: u32,
    spawn: u32,
    pid: u32,

    /// What `readQueue` reports for a claimed entry whose fields do not parse:
    /// no runner's claims list it.
    const unreadable: Claim = .{ .runner = std.math.maxInt(u32), .spawn = 0, .pid = 0 };
};

pub const Entry = struct { index: usize, claim: ?Claim = null };

fn formatEntry(buf: *[entry_len]u8, index: usize) !void {
    _ = try std.fmt.bufPrint(buf, "{d:0>9} - 000 000000 0000000000\n", .{index});
}

/// Write `indices` as a queue of unclaimed entries at `path`, in that order:
/// whole to a temporary file, then renamed over `path`, so no runner ever
/// opens half a queue.
pub fn writeQueue(allocator: Allocator, path: []const u8, indices: []const usize) !void {
    const bytes = try allocator.alloc(u8, indices.len * entry_len);
    defer allocator.free(bytes);
    for (indices, 0..) |index, i| formatEntry(bytes[i * entry_len ..][0..entry_len], index) catch return error.QueueFieldTooWide;
    const tmp = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(tmp);
    const io = host.io();
    {
        const file = try host.cwd().createFile(io, tmp, .{ .truncate = true });
        defer file.close(io);
        try file.writeStreamingAll(io, bytes);
    }
    try host.cwd().rename(tmp, host.cwd(), path, io);
}

/// Every entry of the queue at `path`, in queue order. Caller owns the slice.
pub fn readQueue(allocator: Allocator, path: []const u8) ![]Entry {
    const bytes = try host.cwd().readFileAlloc(host.io(), path, allocator, .limited(512 * 1024 * 1024));
    defer allocator.free(bytes);
    const n = bytes.len / entry_len;
    const entries = try allocator.alloc(Entry, n);
    errdefer allocator.free(entries);
    for (entries, 0..) |*e, i| {
        const line = bytes[i * entry_len ..][0..entry_len];
        e.* = .{ .index = std.fmt.parseInt(usize, line[0..9], 10) catch return error.QueueCorrupt };
        if (line[state_at] == claimed) e.claim = parseClaim(line[fields_at..][0..fields_len]) catch Claim.unreadable;
    }
    return entries;
}

fn parseClaim(fields: *const [fields_len]u8) !Claim {
    return .{
        .runner = try std.fmt.parseInt(u32, fields[0..3], 10),
        .spawn = try std.fmt.parseInt(u32, fields[4..10], 10),
        .pid = try std.fmt.parseInt(u32, fields[11..21], 10),
    };
}

/// True when every entry of the queue at `path` is claimed. Claims are a
/// prefix of the queue, so that is the last entry's state.
pub fn isDrained(path: []const u8) !bool {
    const io = host.io();
    const file = try host.cwd().openFile(io, path, .{});
    defer file.close(io);
    const n = try file.length(io) / entry_len;
    if (n == 0) return true;
    var state: [1]u8 = undefined;
    if (try file.readPositionalAll(io, &state, (n - 1) * entry_len + state_at) != 1) return error.QueueTruncated;
    return state[0] == claimed;
}

/// A runner's side of the queue: one descriptor, and the lock taken on it for
/// each claim. Each child opens its own - flock(2) excludes descriptors from
/// separate opens, in one process or in several.
pub const Claimer = struct {
    file: std.Io.File,
    /// Entries in the queue; it never grows.
    entries: u64,
    /// This claimer's `{runner} {spawn} {pid}`, as every claim writes it.
    fields: [fields_len]u8,
    /// The supervisor that started this runner (its parent when it opened the
    /// queue). An orphan - its supervisor killed, a new run perhaps resumed
    /// in the same directory - claims nothing.
    parent: std.c.pid_t,
    /// Set when `claim` refused because the supervisor is gone.
    orphaned: bool = false,
    /// Entries below this are known to be claimed: claims only ever move it
    /// forward.
    hint: u64 = 0,

    pub fn open(path: []const u8, runner: u32, spawn: u32) !Claimer {
        const io = host.io();
        const file = try host.cwd().openFile(io, path, .{ .mode = .read_write });
        errdefer file.close(io);
        var c: Claimer = .{
            .file = file,
            .entries = try file.length(io) / entry_len,
            .fields = undefined,
            .parent = std.c.getppid(),
        };
        const pid: u32 = @intCast(std.c.getpid());
        _ = std.fmt.bufPrint(&c.fields, "{d:0>3} {d:0>6} {d:0>10}", .{ runner, spawn, pid }) catch return error.QueueFieldTooWide;
        return c;
    }

    pub fn close(self: *Claimer) void {
        self.file.close(host.io());
    }

    /// Claim the next unclaimed file for this runner: its worklist index, or
    /// null when the queue is drained or the supervisor is gone.
    pub fn claim(self: *Claimer) !?usize {
        if (std.c.getppid() != self.parent) {
            self.orphaned = true;
            return null;
        }
        const io = host.io();
        try self.file.lock(io, .exclusive);
        defer self.file.unlock(io);
        const first = try self.firstUnclaimed();
        if (first >= self.entries) return null;
        const at = first * entry_len;
        var head: [9]u8 = undefined;
        if (try self.file.readPositionalAll(io, &head, at) != head.len) return error.QueueTruncated;
        const index = std.fmt.parseInt(usize, &head, 10) catch return error.QueueCorrupt;
        // The fields, then the state byte that makes them a claim: a claimer
        // killed between the two leaves the entry unclaimed.
        try self.file.writePositionalAll(io, &self.fields, at + fields_at);
        try self.file.writePositionalAll(io, &.{claimed}, at + state_at);
        self.hint = first + 1;
        return index;
    }

    fn stateAt(self: *Claimer, pos: u64) !u8 {
        var state: [1]u8 = undefined;
        if (try self.file.readPositionalAll(host.io(), &state, pos * entry_len + state_at) != 1) return error.QueueTruncated;
        return state[0];
    }

    /// The first unclaimed entry, by binary search: claims are a prefix.
    fn firstUnclaimed(self: *Claimer) !u64 {
        var lo = self.hint;
        var hi = self.entries;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (try self.stateAt(mid) == claimed) lo = mid + 1 else hi = mid;
        }
        return lo;
    }
};

// ============================================================================
// The runner's side
// ============================================================================

/// True when `stop_file` names a file that exists.
pub fn stopRequested(stop_file: ?[]const u8) bool {
    const path = stop_file orelse return false;
    host.cwd().access(host.io(), path, .{}) catch return false;
    return true;
}

/// The files a runner process runs, one at a time: its worklist in order, or,
/// with a claimer, whatever it claims next from its supervisor's queue. It
/// stops before the next file when the stop file exists, or after
/// `max_files` files.
pub const FileSource = struct {
    /// Files in this process's worklist.
    count: usize,
    /// Worklist index of the process's first file (a resumed static child).
    base_index: usize = 0,
    claimer: ?*Claimer = null,
    stop_file: ?[]const u8 = null,
    /// Stop after this many files; 0 is no limit.
    max_files: usize = 0,
    taken: usize = 0,
    next_offset: usize = 0,
    /// Why `next` returned null.
    end: ?End = null,

    pub const End = enum { done, stop_file, limit, orphaned };

    /// The offset into the worklist of the next file to run, or null.
    pub fn next(self: *FileSource) !?usize {
        if (self.max_files > 0 and self.taken >= self.max_files) {
            self.end = .limit;
            return null;
        }
        if (stopRequested(self.stop_file)) {
            self.end = .stop_file;
            return null;
        }
        if (self.claimer) |c| {
            const index = (try c.claim()) orelse {
                self.end = if (c.orphaned) .orphaned else .done;
                return null;
            };
            if (index < self.base_index or index - self.base_index >= self.count) return error.ClaimOutsideWorklist;
            self.taken += 1;
            return index - self.base_index;
        }
        if (self.next_offset >= self.count) {
            self.end = .done;
            return null;
        }
        const offset = self.next_offset;
        self.next_offset += 1;
        self.taken += 1;
        return offset;
    }
};

// ============================================================================
// The supervisor's side
// ============================================================================

/// Runner `runner`'s journal in `output_dir`. The streams and heartbeats are
/// named from it (options.resultsStreamPath, stall_watchdog.heartbeatPath).
pub fn slotJournalPath(allocator: Allocator, output_dir: []const u8, runner: usize) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/journal.shard{d}.jsonl", .{ output_dir, runner });
}

fn slotStreamPath(allocator: Allocator, output_dir: []const u8, runner: usize) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/journal.shard{d}.wptreport.jsonl", .{ output_dir, runner });
}

/// How a child ended.
pub const Exit = struct {
    how: How,
    /// For `.crashed`: how the process ended, as the journal's
    /// "process terminated: <detail>" says it.
    detail_buf: [96]u8 = undefined,
    detail_len: usize = 0,

    pub const How = enum { clean, crashed, hung };

    pub fn crashed(comptime fmt: []const u8, args: anytype) Exit {
        var e: Exit = .{ .how = .crashed };
        var w: std.Io.Writer = .fixed(&e.detail_buf);
        w.print(fmt, args) catch {};
        e.detail_len = w.buffered().len;
        return e;
    }

    pub fn detail(self: *const Exit) []const u8 {
        return self.detail_buf[0..self.detail_len];
    }
};

/// One child the supervisor starts: it claims from `queue_path` as `runner`,
/// child number `spawn` of that runner, runs `worklist_path`'s files and
/// journals to `journal_path`.
pub const Child = struct {
    runner: u32,
    spawn: u32,
    worklist_path: []const u8,
    queue_path: []const u8,
    journal_path: []const u8,
};

/// Starts a child and waits for it. The runner's spawns a process and watches
/// it with the stall watchdog (main.zig); the tests run the child's logic on
/// the calling thread. Called from every runner's thread at once.
pub const Launcher = struct {
    context: ?*anyopaque,
    run: *const fn (context: ?*anyopaque, child: Child) anyerror!Exit,
};

/// Where the supervisor's lines go (main.zig's print). Called from every
/// runner's thread at once.
pub const Reporter = struct {
    context: ?*anyopaque = null,
    write: *const fn (context: ?*anyopaque, text: []const u8) void = discard,

    fn discard(_: ?*anyopaque, _: []const u8) void {}

    pub fn say(self: Reporter, comptime fmt: []const u8, args: anytype) void {
        var buf: [2048]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        w.print(fmt, args) catch {};
        self.write(self.context, w.buffered());
    }
};

pub const Plan = struct {
    allocator: Allocator,
    /// The run's worklist: a record's index is a position in it.
    paths: []const []const u8,
    /// Where the worklist, the queue and the runners' journals go.
    output_dir: []const u8,
    /// Runners at once; never more than there are files to run.
    runners: usize,
    /// Checked before every child and by every child before every claim.
    stop_file: ?[]const u8 = null,
    /// Keep what an earlier run of the same worklist in `output_dir` journalled.
    resume_run: bool = false,
    /// For the TIMEOUT record of a child the watchdog killed.
    stall_limit_ms: u64 = stall_watchdog.default_stall_limit_ms,
    launcher: Launcher,
    reporter: Reporter = .{},
    /// Children in a row that may end before claiming a file before their
    /// runner gives up (a runner that cannot start must not spin).
    max_empty_spawns: u32 = 3,
    /// The runner build this run is (journal.Build), stamped on the records
    /// the supervisor writes for its children.
    build: ?journal.Build = null,
};

pub const Outcome = enum {
    /// Every file is journalled.
    finished,
    /// The stop file ended the run with files left; resume it.
    stopped,
};

/// Run `plan.paths` through the queue to the end, or until the stop file.
/// The runners' journals are left in `plan.output_dir`; `writeMerged` folds
/// them into the run's journal.
pub fn run(plan: Plan) !Outcome {
    const a = plan.allocator;
    const io = host.io();
    host.cwd().createDirPath(io, plan.output_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
    const total = plan.paths.len;
    if (plan.runners == 0 or plan.runners > max_runners) return error.RunnerCountOutOfRange;
    const worklist_path = try std.fs.path.join(a, &.{ plan.output_dir, "worklist.txt" });
    defer a.free(worklist_path);
    const queue_path = try std.fs.path.join(a, &.{ plan.output_dir, "queue.txt" });
    defer a.free(queue_path);

    const resumed = plan.resume_run and try sameWorklist(a, worklist_path, plan.paths);
    if (!resumed) {
        if (plan.resume_run) plan.reporter.say("--resume: no earlier run of this worklist in {s}; starting afresh\n", .{plan.output_dir});
        try clearRun(a, plan.output_dir);
        try writeWorklistFile(a, worklist_path, plan.paths);
    }

    var todo = try unjournalled(a, plan.output_dir, total);
    defer a.free(todo);
    if (resumed) plan.reporter.say("Resuming {s}: {d} of {d} files journalled, {d} to run\n", .{ plan.output_dir, total - todo.len, total, todo.len });

    var round: u32 = 0;
    while (todo.len > 0) {
        if (stopRequested(plan.stop_file)) return .stopped;
        round += 1;
        try archiveQueue(a, plan.output_dir, queue_path);
        try writeQueue(a, queue_path, todo);
        try runRound(&plan, worklist_path, queue_path, @min(plan.runners, todo.len));
        if (stopRequested(plan.stop_file) and !try isDrained(queue_path)) return .stopped;

        const missing = try unjournalled(a, plan.output_dir, total);
        a.free(todo);
        todo = missing;
        if (todo.len == 0) break;
        if (round >= 2) {
            try journalNotRun(&plan, todo);
            break;
        }
        plan.reporter.say("\nSupervisor: {d} file(s) queued but never journalled (first: [{d}] {s}); running them again\n\n", .{ todo.len, todo[0], plan.paths[todo[0]] });
    }
    return .finished;
}

/// The runners of one round, each on its own thread, until the queue is
/// drained, the stop file appears or the runner gives up.
fn runRound(plan: *const Plan, worklist_path: []const u8, queue_path: []const u8, runners: usize) !void {
    const a = plan.allocator;
    const runs = try a.alloc(SlotRun, runners);
    defer a.free(runs);
    for (runs, 0..) |*r, i| {
        r.* = .{ .plan = plan, .worklist_path = worklist_path, .queue_path = queue_path, .runner = @intCast(i) };
        // Every runner has a journal from the start, so the run's journals
        // are the runners' 0..n-1 whatever their children did.
        const jp = try slotJournalPath(a, plan.output_dir, i);
        defer a.free(jp);
        var j = try journal.Journal.append(a, jp);
        j.deinit();
    }
    var started: usize = 0;
    {
        // A thread that cannot start ends the round, once the started ones end.
        errdefer for (runs[0..started]) |*r| r.thread.join();
        while (started < runners) : (started += 1) runs[started].thread = try std.Thread.spawn(.{}, SlotRun.entry, .{&runs[started]});
    }
    for (runs) |*r| r.thread.join();
    for (runs) |*r| if (r.failure) |err| return err;
}

/// One runner of a round: its thread, and the error that ended it.
const SlotRun = struct {
    plan: *const Plan,
    worklist_path: []const u8,
    queue_path: []const u8,
    runner: u32,
    thread: std.Thread = undefined,
    failure: ?anyerror = null,

    fn entry(self: *SlotRun) void {
        // This thread's alternate signal stack, for a stack overflow's report (signal_stack.zig).
        const signal_stack = @import("signal_stack.zig").attach();
        defer @import("signal_stack.zig").detach(signal_stack);
        self.loop() catch |err| {
            self.failure = err;
        };
    }

    /// Keep a child going while there is work: start one, wait for it, and
    /// journal what it claimed and did not journal.
    fn loop(self: *SlotRun) !void {
        const plan = self.plan;
        const a = plan.allocator;
        const jp = try slotJournalPath(a, plan.output_dir, self.runner);
        defer a.free(jp);
        var label_buf: [32]u8 = undefined;
        const label = std.fmt.bufPrint(&label_buf, "[runner {d}] ", .{self.runner}) catch "";
        var spawn: u32 = 0;
        var empty: u32 = 0;
        while (true) {
            if (stopRequested(plan.stop_file)) return;
            if (try isDrained(self.queue_path)) return;
            spawn += 1;
            const exit = try plan.launcher.run(plan.launcher.context, .{
                .runner = self.runner,
                .spawn = spawn,
                .worklist_path = self.worklist_path,
                .queue_path = self.queue_path,
                .journal_path = jp,
            });

            const mine = try claimsOf(a, self.queue_path, self.runner, spawn);
            defer a.free(mine);
            var log = try journal.read(a, jp);
            defer log.deinit();
            // Only a child's last claim can be unjournalled - it journals a
            // file before it claims the next - but every claim is checked.
            var blamed: usize = 0;
            for (mine) |index| {
                if (hasRecord(&log, index)) continue;
                blamed += 1;
                try self.blame(jp, label, index, &exit);
            }

            if (mine.len > 0) {
                empty = 0;
                if (blamed == 0) switch (exit.how) {
                    .hung => plan.reporter.say("{s}!!! child {d} made no progress for {d}ms after its last file and was killed; no file blamed\n", .{ label, spawn, plan.stall_limit_ms }),
                    .crashed => plan.reporter.say("{s}!!! child {d} ended between files ({s}); no file blamed\n", .{ label, spawn, exit.detail() }),
                    .clean => {},
                };
                continue;
            }
            switch (exit.how) {
                .clean => {
                    // Nothing claimed and a clean exit: the queue drained or
                    // the stop file appeared before its first claim - or the
                    // child stops for a reason of its own, which another child
                    // would repeat.
                    if (stopRequested(plan.stop_file) or try isDrained(self.queue_path)) return;
                    plan.reporter.say("{s}child {d} exited cleanly without claiming a file; stopping this runner\n", .{ label, spawn });
                    return;
                },
                .crashed, .hung => {
                    empty += 1;
                    plan.reporter.say("{s}!!! child {d} ended ({s}) before claiming a file\n", .{ label, spawn, if (exit.how == .hung) "killed: no progress" else exit.detail() });
                    if (empty >= plan.max_empty_spawns) {
                        plan.reporter.say("{s}giving up: {d} children in a row ended before claiming a file; the other runners take its files\n", .{ label, empty });
                        return;
                    }
                },
            }
        }
    }

    /// Journal `index`, which this runner's child claimed and did not journal,
    /// as the static loop journalled the file a child died on.
    fn blame(self: *SlotRun, jp: []const u8, label: []const u8, index: usize, exit: *const Exit) !void {
        const plan = self.plan;
        const a = plan.allocator;
        const path = plan.paths[index];
        var j = try journal.Journal.append(a, jp);
        defer j.deinit();
        j.build = plan.build;
        switch (exit.how) {
            .crashed => {
                plan.reporter.say("\n{s}!!! crashed on [{d}] {s} ({s})\n\n", .{ label, index, path, exit.detail() });
                const message = try std.fmt.allocPrint(a, "process terminated: {s}", .{exit.detail()});
                defer a.free(message);
                try j.record(.{ .index = index, .path = path, .status = .crash, .message = message });
            },
            .hung => {
                // A hang is not a crash: nothing faulted, the file never
                // finished. It goes in the timeout column, not the crash one.
                plan.reporter.say("\n{s}!!! hung on [{d}] {s} (no progress for {d}ms; killed)\n\n", .{ label, index, path, plan.stall_limit_ms });
                const message = try std.fmt.allocPrint(a, "supervisor killed a child that made no progress for {d}ms", .{plan.stall_limit_ms});
                defer a.free(message);
                try j.record(.{ .index = index, .path = path, .status = .timeout, .message = message });
            },
            .clean => {
                plan.reporter.say("\n{s}!!! child exited cleanly without journalling [{d}] {s}\n\n", .{ label, index, path });
                try j.record(.{ .index = index, .path = path, .status = .@"error", .message = "the runner exited cleanly without journalling this file (work_queue.zig)" });
            },
        }
    }
};

/// The worklist indices runner `runner`'s child `spawn` claimed, in claim order.
fn claimsOf(allocator: Allocator, queue_path: []const u8, runner: u32, spawn: u32) ![]usize {
    const entries = try readQueue(allocator, queue_path);
    defer allocator.free(entries);
    var out: std.ArrayList(usize) = .empty;
    errdefer out.deinit(allocator);
    for (entries) |e| {
        const c = e.claim orelse continue;
        if (c.runner == runner and c.spawn == spawn) try out.append(allocator, e.index);
    }
    return out.toOwnedSlice(allocator);
}

fn hasRecord(log: *const journal.Log, index: usize) bool {
    for (log.records) |rec| if (rec.index == index) return true;
    return false;
}

fn exists(path: []const u8) bool {
    host.cwd().access(host.io(), path, .{}) catch return false;
    return true;
}

/// The worklist indices below `total` that no runner journal in `output_dir`
/// has a record of, in order. Caller owns the slice.
fn unjournalled(allocator: Allocator, output_dir: []const u8, total: usize) ![]usize {
    const seen = try allocator.alloc(bool, total);
    defer allocator.free(seen);
    @memset(seen, false);
    for (0..max_runners) |i| {
        const jp = try slotJournalPath(allocator, output_dir, i);
        defer allocator.free(jp);
        if (!exists(jp)) continue;
        var log = try journal.read(allocator, jp);
        defer log.deinit();
        for (log.records) |rec| {
            if (rec.index < total) seen[rec.index] = true;
        }
    }
    var out: std.ArrayList(usize) = .empty;
    errdefer out.deinit(allocator);
    for (seen, 0..) |s, i| if (!s) try out.append(allocator, i);
    return out.toOwnedSlice(allocator);
}

/// After a second round: journal each file still unjournalled as ERROR, so
/// the run's journal names every file of the worklist once.
fn journalNotRun(plan: *const Plan, indices: []const usize) !void {
    const a = plan.allocator;
    const jp = try slotJournalPath(a, plan.output_dir, 0);
    defer a.free(jp);
    var j = try journal.Journal.append(a, jp);
    defer j.deinit();
    j.build = plan.build;
    plan.reporter.say("\nSupervisor: {d} file(s) still not journalled after a second round; journalled ERROR \"not run\" (first: [{d}] {s})\n\n", .{ indices.len, indices[0], plan.paths[indices[0]] });
    for (indices) |index| try j.record(.{
        .index = index,
        .path = plan.paths[index],
        .status = .@"error",
        .message = "not run: no runner journalled it in two rounds of the shared queue (work_queue.zig)",
    });
}

fn sameWorklist(allocator: Allocator, worklist_path: []const u8, paths: []const []const u8) !bool {
    var existing = selection.readWorklist(allocator, worklist_path) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer existing.deinit();
    if (existing.paths.len != paths.len) return false;
    for (existing.paths, paths) |x, y| if (!std.mem.eql(u8, x, y)) return false;
    return true;
}

fn writeWorklistFile(allocator: Allocator, path: []const u8, paths: []const []const u8) !void {
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try selection.writeWorklist(&out.writer, paths);
    try host.cwd().writeFile(host.io(), .{ .sub_path = path, .data = out.written() });
}

/// A fresh run in `output_dir`: no runner journal, stream or heartbeat, and
/// no queue, of an earlier run is left to be read as this one's.
fn clearRun(allocator: Allocator, output_dir: []const u8) !void {
    const io = host.io();
    for (0..max_runners) |i| {
        const jp = try slotJournalPath(allocator, output_dir, i);
        defer allocator.free(jp);
        const sp = try slotStreamPath(allocator, output_dir, i);
        defer allocator.free(sp);
        const hp = try stall_watchdog.heartbeatPath(allocator, jp);
        defer allocator.free(hp);
        for ([_][]const u8{ jp, sp, hp }) |p| host.cwd().deleteFile(io, p) catch {};
    }
    const q = try std.fs.path.join(allocator, &.{ output_dir, "queue.txt" });
    defer allocator.free(q);
    host.cwd().deleteFile(io, q) catch {};
    var n: usize = 1;
    while (true) : (n += 1) {
        const old = try std.fmt.allocPrint(allocator, "{s}/queue.{d}.txt", .{ output_dir, n });
        defer allocator.free(old);
        host.cwd().deleteFile(io, old) catch break;
    }
}

/// Keep an earlier round's or run's queue as `queue.<n>.txt`: which process
/// claimed which files, for a shard-prefix replay.
fn archiveQueue(allocator: Allocator, output_dir: []const u8, queue_path: []const u8) !void {
    if (!exists(queue_path)) return;
    var n: usize = 1;
    while (true) : (n += 1) {
        const old = try std.fmt.allocPrint(allocator, "{s}/queue.{d}.txt", .{ output_dir, n });
        defer allocator.free(old);
        if (exists(old)) continue;
        try host.cwd().rename(queue_path, host.cwd(), old, host.io());
        return;
    }
}

/// The runners' journals of a run, folded into one in worklist order.
pub const Merged = struct {
    allocator: Allocator,
    /// The runners' journals; `records` points into them.
    logs: []journal.Log,
    /// One record per file, by worklist index; the first of a file's records
    /// stands.
    records: []journal.Record,
    /// Records of a file that already had one.
    duplicates: usize,
    /// Worklist indices below the run's total with no record.
    missing: usize,

    pub fn deinit(self: *Merged) void {
        for (self.logs) |*l| l.deinit();
        self.allocator.free(self.logs);
        self.allocator.free(self.records);
    }
};

pub fn merge(allocator: Allocator, output_dir: []const u8, total: usize) !Merged {
    var logs: std.ArrayList(journal.Log) = .empty;
    errdefer {
        for (logs.items) |*l| l.deinit();
        logs.deinit(allocator);
    }
    var count: usize = 0;
    for (0..max_runners) |i| {
        const jp = try slotJournalPath(allocator, output_dir, i);
        defer allocator.free(jp);
        if (!exists(jp)) continue;
        var log = try journal.read(allocator, jp);
        errdefer log.deinit();
        try logs.append(allocator, log);
        count += log.records.len;
    }

    const all = try allocator.alloc(journal.Record, count);
    defer allocator.free(all);
    var k: usize = 0;
    for (logs.items) |l| for (l.records) |rec| {
        all[k] = rec;
        k += 1;
    };
    // Stable: of a file's records, the first journal's first stands.
    std.mem.sort(journal.Record, all, {}, struct {
        fn less(_: void, x: journal.Record, y: journal.Record) bool {
            return x.index < y.index;
        }
    }.less);

    const seen = try allocator.alloc(bool, total);
    defer allocator.free(seen);
    @memset(seen, false);
    var records: std.ArrayList(journal.Record) = .empty;
    errdefer records.deinit(allocator);
    var duplicates: usize = 0;
    for (all, 0..) |rec, i| {
        const again = if (rec.index < total) seen[rec.index] else i > 0 and all[i - 1].index == rec.index;
        if (again) {
            duplicates += 1;
            continue;
        }
        if (rec.index < total) seen[rec.index] = true;
        try records.append(allocator, rec);
    }
    var missing: usize = 0;
    for (seen) |s| {
        if (!s) missing += 1;
    }

    return .{
        .allocator = allocator,
        .logs = try logs.toOwnedSlice(allocator),
        .records = try records.toOwnedSlice(allocator),
        .duplicates = duplicates,
        .missing = missing,
    };
}

pub const MergeCounts = struct { records: usize, duplicates: usize, missing: usize };

/// Fold the runners' journals in `output_dir` into `journal_path`: written
/// whole beside it, then renamed over it. `build`: the run's runner build,
/// stamped on any record that names none.
pub fn writeMerged(allocator: Allocator, output_dir: []const u8, total: usize, journal_path: []const u8, build: ?journal.Build) !MergeCounts {
    var m = try merge(allocator, output_dir, total);
    defer m.deinit();
    const tmp = try std.fmt.allocPrint(allocator, "{s}.merge-tmp", .{journal_path});
    defer allocator.free(tmp);
    {
        var out = try journal.Journal.create(allocator, tmp);
        defer out.deinit();
        out.build = build;
        for (m.records) |rec| try out.record(rec);
    }
    try host.cwd().rename(tmp, host.cwd(), journal_path, host.io());
    return .{ .records = m.records.len, .duplicates = m.duplicates, .missing = m.missing };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// A scratch directory and its absolute path: journal.zig and this module
/// take paths, as the runner passes them.
const Scratch = struct {
    tmp: testing.TmpDir,
    /// realPathFileAlloc's sentinel slice: freed as it was allocated.
    root: [:0]const u8,

    fn init() !Scratch {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const root = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
        return .{ .tmp = tmp, .root = root };
    }

    fn deinit(self: *Scratch) void {
        testing.allocator.free(self.root);
        self.tmp.cleanup();
    }

    fn path(self: *const Scratch, name: []const u8) ![]u8 {
        return std.fs.path.join(testing.allocator, &.{ self.root, name });
    }
};

fn identity(allocator: Allocator, n: usize) ![]usize {
    const out = try allocator.alloc(usize, n);
    for (out, 0..) |*x, i| x.* = i;
    return out;
}

test "a fresh queue lists every index unclaimed, in the order given" {
    var s = try Scratch.init();
    defer s.deinit();
    const q = try s.path("queue.txt");
    defer testing.allocator.free(q);
    try writeQueue(testing.allocator, q, &.{ 4, 0, 7, 2 });
    const entries = try readQueue(testing.allocator, q);
    defer testing.allocator.free(entries);
    try testing.expectEqual(@as(usize, 4), entries.len);
    for (entries, [_]usize{ 4, 0, 7, 2 }) |e, want| {
        try testing.expectEqual(want, e.index);
        try testing.expect(e.claim == null);
    }
    try testing.expect(!try isDrained(q));
}

test "claims hand out each queued index once, in queue order, then nothing; each names its runner, spawn and pid" {
    var s = try Scratch.init();
    defer s.deinit();
    const q = try s.path("queue.txt");
    defer testing.allocator.free(q);
    try writeQueue(testing.allocator, q, &.{ 3, 1, 2 });
    var c = try Claimer.open(q, 2, 7);
    defer c.close();
    try testing.expectEqual(@as(?usize, 3), try c.claim());
    try testing.expectEqual(@as(?usize, 1), try c.claim());
    try testing.expect(!try isDrained(q));
    try testing.expectEqual(@as(?usize, 2), try c.claim());
    try testing.expectEqual(@as(?usize, null), try c.claim());
    try testing.expect(try isDrained(q));
    const entries = try readQueue(testing.allocator, q);
    defer testing.allocator.free(entries);
    for (entries) |e| {
        const claim = e.claim orelse return error.TestUnclaimed;
        try testing.expectEqual(@as(u32, 2), claim.runner);
        try testing.expectEqual(@as(u32, 7), claim.spawn);
        try testing.expectEqual(@as(u32, @intCast(std.c.getpid())), claim.pid);
    }
}

fn claimAll(q: []const u8, runner: u32, got: *std.ArrayList(usize), failure: *?anyerror) void {
    var c = Claimer.open(q, runner, 1) catch |err| {
        failure.* = err;
        return;
    };
    defer c.close();
    while (true) {
        const index = (c.claim() catch |err| {
            failure.* = err;
            return;
        }) orelse return;
        got.append(testing.allocator, index) catch |err| {
            failure.* = err;
            return;
        };
    }
}

test "runners claiming at once through their own descriptors never get the same index" {
    var s = try Scratch.init();
    defer s.deinit();
    const q = try s.path("queue.txt");
    defer testing.allocator.free(q);
    const n = 400;
    const all = try identity(testing.allocator, n);
    defer testing.allocator.free(all);
    try writeQueue(testing.allocator, q, all);

    var got: [4]std.ArrayList(usize) = .{ .empty, .empty, .empty, .empty };
    defer for (&got) |*g| g.deinit(testing.allocator);
    var failures: [4]?anyerror = .{ null, null, null, null };
    var threads: [4]std.Thread = undefined;
    for (&threads, 0..) |*t, r| t.* = try std.Thread.spawn(.{}, claimAll, .{ q, @as(u32, @intCast(r)), &got[r], &failures[r] });
    for (threads) |t| t.join();
    for (failures) |f| if (f) |err| return err;

    var seen = try testing.allocator.alloc(u8, n);
    defer testing.allocator.free(seen);
    @memset(seen, 0);
    for (got) |g| for (g.items) |index| {
        seen[index] += 1;
    };
    for (seen) |count| try testing.expectEqual(@as(u8, 1), count);
    // ... and the queue agrees on who took each one.
    const entries = try readQueue(testing.allocator, q);
    defer testing.allocator.free(entries);
    for (entries) |e| {
        const claim = e.claim orelse return error.TestUnclaimed;
        try testing.expect(std.mem.indexOfScalar(usize, got[claim.runner].items, e.index) != null);
    }
}

test "a claimer that died after writing its claim's fields but before its state byte left the entry unclaimed" {
    var s = try Scratch.init();
    defer s.deinit();
    const q = try s.path("queue.txt");
    defer testing.allocator.free(q);
    try writeQueue(testing.allocator, q, &.{ 0, 1, 2 });
    var first = try Claimer.open(q, 0, 1);
    defer first.close();
    try testing.expectEqual(@as(?usize, 0), try first.claim());
    // Entry 1's fields as a claimer killed between its two writes leaves them.
    {
        const file = try host.cwd().openFile(host.io(), q, .{ .mode = .read_write });
        defer file.close(host.io());
        try file.writePositionalAll(host.io(), "009 000042 0000099999", entry_len + 12);
    }
    var second = try Claimer.open(q, 1, 1);
    defer second.close();
    try testing.expectEqual(@as(?usize, 1), try second.claim());
    const entries = try readQueue(testing.allocator, q);
    defer testing.allocator.free(entries);
    try testing.expectEqual(@as(u32, 1), entries[1].claim.?.runner);
    try testing.expect(entries[2].claim == null);
}

test "a runner whose supervisor is gone claims nothing" {
    var s = try Scratch.init();
    defer s.deinit();
    const q = try s.path("queue.txt");
    defer testing.allocator.free(q);
    try writeQueue(testing.allocator, q, &.{ 0, 1 });
    var c = try Claimer.open(q, 0, 1);
    defer c.close();
    // Not this process's parent: what an orphan sees once its supervisor died.
    c.parent = -1;
    try testing.expectEqual(@as(?usize, null), try c.claim());
    try testing.expect(c.orphaned);
    const entries = try readQueue(testing.allocator, q);
    defer testing.allocator.free(entries);
    try testing.expect(entries[0].claim == null);
}

test "a worklist source yields its offsets in order, stops at a stop file before the next file, and at its limit" {
    var s = try Scratch.init();
    defer s.deinit();
    var plain: FileSource = .{ .count = 3 };
    try testing.expectEqual(@as(?usize, 0), try plain.next());
    try testing.expectEqual(@as(?usize, 1), try plain.next());
    try testing.expectEqual(@as(?usize, 2), try plain.next());
    try testing.expectEqual(@as(?usize, null), try plain.next());
    try testing.expectEqual(FileSource.End.done, plain.end.?);

    const stop = try s.path("STOP");
    defer testing.allocator.free(stop);
    var stoppable: FileSource = .{ .count = 3, .stop_file = stop };
    try testing.expectEqual(@as(?usize, 0), try stoppable.next());
    try s.tmp.dir.writeFile(testing.io, .{ .sub_path = "STOP", .data = "" });
    try testing.expectEqual(@as(?usize, null), try stoppable.next());
    try testing.expectEqual(FileSource.End.stop_file, stoppable.end.?);

    var limited: FileSource = .{ .count = 5, .max_files = 2 };
    try testing.expectEqual(@as(?usize, 0), try limited.next());
    try testing.expectEqual(@as(?usize, 1), try limited.next());
    try testing.expectEqual(@as(?usize, null), try limited.next());
    try testing.expectEqual(FileSource.End.limit, limited.end.?);
}

test "a queue source yields the offsets it claims, and checks the stop file before it claims" {
    var s = try Scratch.init();
    defer s.deinit();
    const q = try s.path("queue.txt");
    defer testing.allocator.free(q);
    const stop = try s.path("STOP");
    defer testing.allocator.free(stop);
    try writeQueue(testing.allocator, q, &.{ 2, 0, 1 });
    var c = try Claimer.open(q, 0, 1);
    defer c.close();
    var source: FileSource = .{ .count = 3, .claimer = &c, .stop_file = stop };
    try testing.expectEqual(@as(?usize, 2), try source.next());
    try s.tmp.dir.writeFile(testing.io, .{ .sub_path = "STOP", .data = "" });
    try testing.expectEqual(@as(?usize, null), try source.next());
    try testing.expectEqual(FileSource.End.stop_file, source.end.?);
    // The stop left the rest unclaimed, for a resumed run.
    const entries = try readQueue(testing.allocator, q);
    defer testing.allocator.free(entries);
    try testing.expect(entries[1].claim == null);
    try testing.expect(entries[2].claim == null);
}

// ---------------------------------------------------------------------------
// The supervisor, driven by a launcher whose "children" run on the runner
// threads: they claim through Claimer and FileSource and journal through
// journal.Journal exactly as the runner's children do; only the process is
// missing.
// ---------------------------------------------------------------------------

const Behaviour = enum {
    pass,
    /// Claims the file and dies before journalling it.
    crash,
    /// Claims the file and never finishes it (the supervisor's watchdog kills it).
    hang,
    /// Journals the file, then dies before claiming the next.
    die_after,
    /// Journals the file, then the stop file appears.
    stop_after,
    /// Claims the file, then its claim becomes unreadable (as if torn), and it dies:
    /// the supervisor cannot tell this file was its. Once only.
    lose_claim,
};

const World = struct {
    paths: []const []const u8,
    behaviour: []Behaviour,
    stop_file: ?[]const u8 = null,
    files_per_child: usize = 0,
    /// Every child of this runner dies before claiming anything.
    dead_runner: ?u32 = null,
    spawns: std.atomic.Value(u32) = .init(0),
    lost: std.atomic.Value(bool) = .init(false),

    fn launcher(self: *World) Launcher {
        return .{ .context = self, .run = runChild };
    }

    fn runChild(context: ?*anyopaque, child: Child) anyerror!Exit {
        const w: *World = @ptrCast(@alignCast(context.?));
        _ = w.spawns.fetchAdd(1, .monotonic);
        if (w.dead_runner) |dead| if (dead == child.runner) return Exit.crashed("{s}", .{"signal 6"});
        var claimer = try Claimer.open(child.queue_path, child.runner, child.spawn);
        defer claimer.close();
        var source: FileSource = .{ .count = w.paths.len, .claimer = &claimer, .stop_file = w.stop_file, .max_files = w.files_per_child };
        var j = try journal.Journal.append(testing.allocator, child.journal_path);
        defer j.deinit();
        while (try source.next()) |i| {
            switch (w.behaviour[i]) {
                .crash => return Exit.crashed("{s}", .{"signal 11"}),
                .hang => return .{ .how = .hung },
                .lose_claim => if (!w.lost.swap(true, .acq_rel)) {
                    try tearClaim(child.queue_path, i);
                    return Exit.crashed("{s}", .{"signal 11"});
                },
                else => {},
            }
            try j.record(resultOf(i, w.paths[i]));
            switch (w.behaviour[i]) {
                .die_after => return Exit.crashed("{s}", .{"signal 11"}),
                .stop_after => if (w.stop_file) |sf| try host.cwd().writeFile(host.io(), .{ .sub_path = sf, .data = "" }),
                else => {},
            }
        }
        return .{ .how = .clean };
    }
};

/// Overwrite the spawn field of `index`'s claim, so no runner's claims list it.
fn tearClaim(queue_path: []const u8, index: usize) !void {
    const entries = try readQueue(testing.allocator, queue_path);
    defer testing.allocator.free(entries);
    const pos = for (entries, 0..) |e, p| {
        if (e.index == index) break p;
    } else return error.TestNotQueued;
    const file = try host.cwd().openFile(host.io(), queue_path, .{ .mode = .read_write });
    defer file.close(host.io());
    try file.writePositionalAll(host.io(), "999999", pos * entry_len + 16);
}

fn resultOf(index: usize, path: []const u8) journal.Record {
    return .{ .index = index, .path = path, .status = .ok, .passed = index % 7 + 1, .failed = index % 3 };
}

fn testPaths(allocator: Allocator, n: usize) ![]const []const u8 {
    const paths = try allocator.alloc([]const u8, n);
    for (paths, 0..) |*p, i| p.* = try std.fmt.allocPrint(allocator, "dir{d}/test-{d}.html", .{ i % 4, i });
    return paths;
}

fn freePaths(allocator: Allocator, paths: []const []const u8) void {
    for (paths) |p| allocator.free(p);
    allocator.free(paths);
}

const stall_ms: u64 = 150_000;

fn planFor(s: *const Scratch, w: *World, runners: usize, out: []const u8) Plan {
    _ = s;
    return .{
        .allocator = testing.allocator,
        .paths = w.paths,
        .output_dir = out,
        .runners = runners,
        .stop_file = w.stop_file,
        .stall_limit_ms = stall_ms,
        .launcher = w.launcher(),
    };
}

/// Every index journalled exactly once, by the merge.
fn expectExactlyOnce(m: *const Merged, total: usize) !void {
    try testing.expectEqual(@as(usize, 0), m.duplicates);
    try testing.expectEqual(@as(usize, 0), m.missing);
    try testing.expectEqual(total, m.records.len);
    for (m.records, 0..) |rec, i| try testing.expectEqual(i, rec.index);
}

test "every file is journalled exactly once, in worklist order, whatever runner took it" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    const paths = try testPaths(testing.allocator, 60);
    defer freePaths(testing.allocator, paths);
    const behaviour = try testing.allocator.alloc(Behaviour, paths.len);
    defer testing.allocator.free(behaviour);
    @memset(behaviour, .pass);
    var w: World = .{ .paths = paths, .behaviour = behaviour };

    try testing.expectEqual(Outcome.finished, try run(planFor(&s, &w, 4, out)));
    var m = try merge(testing.allocator, out, paths.len);
    defer m.deinit();
    try expectExactlyOnce(&m, paths.len);
    for (m.records, paths) |rec, p| {
        try testing.expectEqualStrings(p, rec.path);
        try testing.expectEqual(journal.Status.ok, rec.status);
    }
    // At most one child per runner: nobody crashed, so nobody was restarted
    // (a runner whose thread starts after the queue drained starts none).
    try testing.expect(w.spawns.load(.monotonic) <= 4);
}

test "a crash is journalled CRASH for the file its child claimed, a hang TIMEOUT, and the runner's next child claims the next unclaimed file" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    const paths = try testPaths(testing.allocator, 40);
    defer freePaths(testing.allocator, paths);
    const behaviour = try testing.allocator.alloc(Behaviour, paths.len);
    defer testing.allocator.free(behaviour);
    @memset(behaviour, .pass);
    behaviour[5] = .crash;
    behaviour[9] = .hang;
    behaviour[17] = .crash;
    behaviour[30] = .die_after;
    var w: World = .{ .paths = paths, .behaviour = behaviour };

    // One runner, so which child claimed what is fixed.
    try testing.expectEqual(Outcome.finished, try run(planFor(&s, &w, 1, out)));
    var m = try merge(testing.allocator, out, paths.len);
    defer m.deinit();
    try expectExactlyOnce(&m, paths.len);
    try testing.expectEqual(journal.Status.crash, m.records[5].status);
    try testing.expectEqualStrings("process terminated: signal 11", m.records[5].message.?);
    try testing.expectEqual(journal.Status.crash, m.records[17].status);
    try testing.expectEqual(journal.Status.timeout, m.records[9].status);
    try testing.expectEqualStrings("supervisor killed a child that made no progress for 150000ms", m.records[9].message.?);
    // A death between files blames no file: 30 kept its own result, 31 ran.
    try testing.expectEqual(journal.Status.ok, m.records[30].status);
    try testing.expectEqual(journal.Status.ok, m.records[31].status);
    // One restart per crash, hang and death, each claiming the next file.
    try testing.expectEqual(@as(u32, 1 + 4), w.spawns.load(.monotonic));
    const q = try std.fs.path.join(testing.allocator, &.{ out, "queue.txt" });
    defer testing.allocator.free(q);
    const entries = try readQueue(testing.allocator, q);
    defer testing.allocator.free(entries);
    for ([_]usize{ 0, 5, 6, 9, 10, 17, 18, 30, 31, 39 }, [_]u32{ 1, 1, 2, 2, 3, 3, 4, 4, 5, 5 }) |index, spawn| {
        try testing.expectEqual(index, entries[index].index);
        try testing.expectEqual(spawn, entries[index].claim.?.spawn);
    }
}

test "results equal a static-shard run's on the same list: only the order the files ran in differs" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    const paths = try testPaths(testing.allocator, 53);
    defer freePaths(testing.allocator, paths);
    const behaviour = try testing.allocator.alloc(Behaviour, paths.len);
    defer testing.allocator.free(behaviour);
    @memset(behaviour, .pass);
    for ([_]usize{ 0, 11, 12, 52 }) |i| behaviour[i] = .crash;
    for ([_]usize{ 7, 40 }) |i| behaviour[i] = .hang;
    var w: World = .{ .paths = paths, .behaviour = behaviour };
    const runners = 5;

    try testing.expectEqual(Outcome.finished, try run(planFor(&s, &w, runners, out)));
    var m = try merge(testing.allocator, out, paths.len);
    defer m.deinit();
    try expectExactlyOnce(&m, paths.len);

    // The static shards' records - each shard its private round-robin slice,
    // a crash journalled CRASH and a hang TIMEOUT by its supervisor - folded
    // back to worklist positions and put in worklist order.
    var static: std.ArrayList(journal.Record) = .empty;
    defer static.deinit(testing.allocator);
    var shard: usize = 0;
    while (shard < runners) : (shard += 1) {
        const indices = try selection.shardIndices(testing.allocator, paths.len, runners, shard);
        defer testing.allocator.free(indices);
        for (indices) |i| try static.append(testing.allocator, switch (behaviour[i]) {
            .crash => .{ .index = i, .path = paths[i], .status = .crash, .message = "process terminated: signal 11" },
            .hang => .{ .index = i, .path = paths[i], .status = .timeout, .message = "supervisor killed a child that made no progress for 150000ms" },
            else => resultOf(i, paths[i]),
        });
    }
    std.mem.sort(journal.Record, static.items, {}, struct {
        fn less(_: void, a: journal.Record, b: journal.Record) bool {
            return a.index < b.index;
        }
    }.less);

    try testing.expectEqual(static.items.len, m.records.len);
    for (static.items, m.records) |want, got| {
        try testing.expectEqual(want.index, got.index);
        try testing.expectEqualStrings(want.path, got.path);
        try testing.expectEqual(want.status, got.status);
        try testing.expectEqual(want.passed, got.passed);
        try testing.expectEqual(want.failed, got.failed);
        if (want.message) |msg| try testing.expectEqualStrings(msg, got.message.?) else try testing.expect(got.message == null);
    }
}

test "a stop file ends the run between files; a resumed run journals only the rest, each once" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    const stop = try s.path("STOP");
    defer testing.allocator.free(stop);
    const paths = try testPaths(testing.allocator, 50);
    defer freePaths(testing.allocator, paths);
    const behaviour = try testing.allocator.alloc(Behaviour, paths.len);
    defer testing.allocator.free(behaviour);
    @memset(behaviour, .pass);
    behaviour[12] = .stop_after;
    var w: World = .{ .paths = paths, .behaviour = behaviour, .stop_file = stop };

    // One runner, so the stop lands after exactly file 12.
    try testing.expectEqual(Outcome.stopped, try run(planFor(&s, &w, 1, out)));
    var first = try merge(testing.allocator, out, paths.len);
    const done_before = first.records.len;
    first.deinit();
    try testing.expectEqual(@as(usize, 13), done_before);

    // The run stays stopped while the stop file stands, and runs nothing.
    var again = planFor(&s, &w, 3, out);
    again.resume_run = true;
    const spawns_before = w.spawns.load(.monotonic);
    try testing.expectEqual(Outcome.stopped, try run(again));
    try testing.expectEqual(spawns_before, w.spawns.load(.monotonic));

    try host.cwd().deleteFile(host.io(), stop);
    behaviour[12] = .pass;
    try testing.expectEqual(Outcome.finished, try run(again));
    var m = try merge(testing.allocator, out, paths.len);
    defer m.deinit();
    try expectExactlyOnce(&m, paths.len);
}

test "resuming against a different worklist starts afresh" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    const paths = try testPaths(testing.allocator, 20);
    defer freePaths(testing.allocator, paths);
    const behaviour = try testing.allocator.alloc(Behaviour, paths.len);
    defer testing.allocator.free(behaviour);
    @memset(behaviour, .pass);
    var w: World = .{ .paths = paths, .behaviour = behaviour };
    try testing.expectEqual(Outcome.finished, try run(planFor(&s, &w, 2, out)));

    // Fewer files, other names: nothing of the first run may be kept.
    const other = try testPaths(testing.allocator, 8);
    defer freePaths(testing.allocator, other);
    var w2: World = .{ .paths = other[3..], .behaviour = behaviour[0..5] };
    var plan = planFor(&s, &w2, 1, out);
    plan.resume_run = true;
    try testing.expectEqual(Outcome.finished, try run(plan));
    var m = try merge(testing.allocator, out, 5);
    defer m.deinit();
    try expectExactlyOnce(&m, 5);
    for (m.records, other[3..]) |rec, p| try testing.expectEqualStrings(p, rec.path);
}

test "a runner whose children die before claiming gives up; the other runners take its files" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    const paths = try testPaths(testing.allocator, 30);
    defer freePaths(testing.allocator, paths);
    const behaviour = try testing.allocator.alloc(Behaviour, paths.len);
    defer testing.allocator.free(behaviour);
    @memset(behaviour, .pass);
    var w: World = .{ .paths = paths, .behaviour = behaviour, .dead_runner = 1 };
    try testing.expectEqual(Outcome.finished, try run(planFor(&s, &w, 3, out)));
    var m = try merge(testing.allocator, out, paths.len);
    defer m.deinit();
    try expectExactlyOnce(&m, paths.len);
    for (m.records) |rec| try testing.expectEqual(journal.Status.ok, rec.status);
}

test "a child that ends at its file limit is replaced, and the queue still drains" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    const paths = try testPaths(testing.allocator, 25);
    defer freePaths(testing.allocator, paths);
    const behaviour = try testing.allocator.alloc(Behaviour, paths.len);
    defer testing.allocator.free(behaviour);
    @memset(behaviour, .pass);
    var w: World = .{ .paths = paths, .behaviour = behaviour, .files_per_child = 4 };
    try testing.expectEqual(Outcome.finished, try run(planFor(&s, &w, 2, out)));
    var m = try merge(testing.allocator, out, paths.len);
    defer m.deinit();
    try expectExactlyOnce(&m, paths.len);
    // 25 files, at most 4 a child: at least 7 children.
    try testing.expect(w.spawns.load(.monotonic) >= 7);
}

test "a file whose claim nobody can attribute is run again in a second round" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    const paths = try testPaths(testing.allocator, 12);
    defer freePaths(testing.allocator, paths);
    const behaviour = try testing.allocator.alloc(Behaviour, paths.len);
    defer testing.allocator.free(behaviour);
    @memset(behaviour, .pass);
    behaviour[6] = .lose_claim;
    var w: World = .{ .paths = paths, .behaviour = behaviour };
    try testing.expectEqual(Outcome.finished, try run(planFor(&s, &w, 2, out)));
    var m = try merge(testing.allocator, out, paths.len);
    defer m.deinit();
    try expectExactlyOnce(&m, paths.len);
    try testing.expectEqual(journal.Status.ok, m.records[6].status);
}

test "a file no runner ever journals is journalled ERROR once, after the second round" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    const paths = try testPaths(testing.allocator, 6);
    defer freePaths(testing.allocator, paths);
    const behaviour = try testing.allocator.alloc(Behaviour, paths.len);
    defer testing.allocator.free(behaviour);
    @memset(behaviour, .pass);
    // The only runner never starts: nothing is claimed in either round.
    var w: World = .{ .paths = paths, .behaviour = behaviour, .dead_runner = 0 };
    try testing.expectEqual(Outcome.finished, try run(planFor(&s, &w, 1, out)));
    var m = try merge(testing.allocator, out, paths.len);
    defer m.deinit();
    try expectExactlyOnce(&m, paths.len);
    for (m.records) |rec| {
        try testing.expectEqual(journal.Status.@"error", rec.status);
        try testing.expect(std.mem.startsWith(u8, rec.message.?, "not run: "));
    }
}

test "the merge counts a file journalled twice, and a file never journalled" {
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    try host.cwd().createDirPath(host.io(), out);
    {
        const p0 = try slotJournalPath(testing.allocator, out, 0);
        defer testing.allocator.free(p0);
        var j = try journal.Journal.create(testing.allocator, p0);
        defer j.deinit();
        try j.record(.{ .index = 2, .path = "c.html", .status = .ok });
        try j.record(.{ .index = 0, .path = "a.html", .status = .ok });
    }
    {
        const p1 = try slotJournalPath(testing.allocator, out, 1);
        defer testing.allocator.free(p1);
        var j = try journal.Journal.create(testing.allocator, p1);
        defer j.deinit();
        try j.record(.{ .index = 2, .path = "c.html", .status = .crash });
    }
    var m = try merge(testing.allocator, out, 4);
    defer m.deinit();
    try testing.expectEqual(@as(usize, 1), m.duplicates);
    // 1 and 3.
    try testing.expectEqual(@as(usize, 2), m.missing);
    try testing.expectEqual(@as(usize, 2), m.records.len);
    try testing.expectEqual(@as(usize, 0), m.records[0].index);
    // The first record of a file stands.
    try testing.expectEqual(journal.Status.ok, m.records[1].status);
}

test "the run's journal names its build on every record, the ones the supervisor wrote included" {
    // A child stamps the records it writes (journal.Journal.build); a CRASH
    // the supervisor journals for a child that died, and the merge, carry the
    // run's build too, so a bug-finding run's journal can never pass for a
    // production one (tools/wpt_progress.py refuses it).
    var s = try Scratch.init();
    defer s.deinit();
    const out = try s.path("out");
    defer testing.allocator.free(out);
    try host.cwd().createDirPath(host.io(), out);
    {
        const p0 = try slotJournalPath(testing.allocator, out, 0);
        defer testing.allocator.free(p0);
        var j = try journal.Journal.create(testing.allocator, p0);
        defer j.deinit();
        j.build = .bug_finding;
        try j.record(.{ .index = 0, .path = "a.html", .status = .ok });
        // An older child's record, with no build of its own.
        j.build = null;
        try j.record(.{ .index = 1, .path = "b.html", .status = .crash });
    }
    const merged = try s.path("journal.jsonl");
    defer testing.allocator.free(merged);
    const counts = try writeMerged(testing.allocator, out, 2, merged, .bug_finding);
    try testing.expectEqual(@as(usize, 2), counts.records);
    var log = try journal.read(testing.allocator, merged);
    defer log.deinit();
    for (log.records) |rec| try testing.expectEqual(@as(?journal.Build, .bug_finding), rec.build);
}
