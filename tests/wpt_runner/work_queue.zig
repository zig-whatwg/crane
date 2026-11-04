//! The shared work queue of a supervised run (`--parallel=N`, `--supervise`).
//!
//! SKELETON (RED): the API and its tests; the bodies come in the next commit.

const std = @import("std");
const host = @import("host");
const journal = @import("journal.zig");
const selection = @import("selection.zig");
const stall_watchdog = @import("stall_watchdog.zig");
const Allocator = std.mem.Allocator;

pub const entry_len: usize = 34;

pub const Claim = struct { runner: u32, spawn: u32, pid: u32 };
pub const Entry = struct { index: usize, claim: ?Claim = null };

pub fn writeQueue(allocator: Allocator, path: []const u8, indices: []const usize) !void {
    _ = allocator;
    _ = path;
    _ = indices;
    return error.Unimplemented;
}

pub fn readQueue(allocator: Allocator, path: []const u8) ![]Entry {
    _ = allocator;
    _ = path;
    return error.Unimplemented;
}

pub fn isDrained(path: []const u8) !bool {
    _ = path;
    return error.Unimplemented;
}

pub const Claimer = struct {
    file: std.Io.File,
    parent: std.c.pid_t,
    orphaned: bool = false,

    pub fn open(path: []const u8, runner: u32, spawn: u32) !Claimer {
        _ = path;
        _ = runner;
        _ = spawn;
        return error.Unimplemented;
    }

    pub fn close(self: *Claimer) void {
        _ = self;
    }

    pub fn claim(self: *Claimer) !?usize {
        _ = self;
        return error.Unimplemented;
    }
};

pub fn stopRequested(stop_file: ?[]const u8) bool {
    _ = stop_file;
    return false;
}

pub const FileSource = struct {
    count: usize,
    base_index: usize = 0,
    claimer: ?*Claimer = null,
    stop_file: ?[]const u8 = null,
    max_files: usize = 0,
    taken: usize = 0,
    next_offset: usize = 0,
    end: ?End = null,

    pub const End = enum { done, stop_file, limit, orphaned };

    pub fn next(self: *FileSource) !?usize {
        _ = self;
        return error.Unimplemented;
    }
};

pub fn slotJournalPath(allocator: Allocator, output_dir: []const u8, runner: usize) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/journal.shard{d}.jsonl", .{ output_dir, runner });
}

pub const Exit = struct {
    how: How,
    detail_buf: [96]u8 = undefined,
    detail_len: usize = 0,

    pub const How = enum { clean, crashed, hung };

    pub fn crashed(comptime fmt: []const u8, args: anytype) Exit {
        var e: Exit = .{ .how = .crashed };
        const s = std.fmt.bufPrint(&e.detail_buf, fmt, args) catch e.detail_buf[0..0];
        e.detail_len = s.len;
        return e;
    }

    pub fn detail(self: *const Exit) []const u8 {
        return self.detail_buf[0..self.detail_len];
    }
};

pub const Child = struct {
    runner: u32,
    spawn: u32,
    worklist_path: []const u8,
    queue_path: []const u8,
    journal_path: []const u8,
};

pub const Launcher = struct {
    context: ?*anyopaque,
    run: *const fn (context: ?*anyopaque, child: Child) anyerror!Exit,
};

pub const Reporter = struct {
    context: ?*anyopaque = null,
    write: *const fn (context: ?*anyopaque, text: []const u8) void = discard,

    fn discard(_: ?*anyopaque, _: []const u8) void {}
};

pub const Plan = struct {
    allocator: Allocator,
    paths: []const []const u8,
    output_dir: []const u8,
    runners: usize,
    stop_file: ?[]const u8 = null,
    resume_run: bool = false,
    stall_limit_ms: u64 = stall_watchdog.default_stall_limit_ms,
    launcher: Launcher,
    reporter: Reporter = .{},
    max_empty_spawns: u32 = 3,
};

pub const Outcome = enum { finished, stopped };

pub fn run(plan: Plan) !Outcome {
    _ = plan;
    return error.Unimplemented;
}

pub const Merged = struct {
    allocator: Allocator,
    logs: []journal.Log,
    records: []journal.Record,
    duplicates: usize,
    missing: usize,

    pub fn deinit(self: *Merged) void {
        for (self.logs) |*l| l.deinit();
        self.allocator.free(self.logs);
        self.allocator.free(self.records);
    }
};

pub fn merge(allocator: Allocator, output_dir: []const u8, total: usize) !Merged {
    _ = allocator;
    _ = output_dir;
    _ = total;
    return error.Unimplemented;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// A scratch directory and its absolute path: journal.zig and this module
/// take paths, as the runner passes them.
const Scratch = struct {
    tmp: testing.TmpDir,
    root: []const u8,

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
