//! The real executor: a compiled Zig test executable run as child
//! processes in the test runner's server mode, the protocol `zig build test`
//! itself speaks (lib/compiler/test_runner.zig mainServer; the build
//! runner's side is compiler/Maker/Step/Run.zig evalZigTest/waitZigTest):
//!
//!   launcher -> child   query_test_metadata          (no body)
//!   child -> launcher   test_metadata                (TestMetadata + names)
//!   launcher -> child   run_test <u32 index>
//!   child -> launcher   test_started, then test_results (status, leaks, logged errors)
//!   launcher -> child   exit
//!
//! So tests are chosen at run time from one compiled binary: no
//! `--test-filter`, which is a compile-time option and would make a new
//! binary per selection.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const InMessage = std.zig.Server.Message;
const sched = @import("scheduler.zig");
const Slots = @import("slots.zig").Slots;

pub const Metadata = struct {
    names: [][]const u8,
    /// Tests that expect a panic (`expected_panic_msgs`); the build runner
    /// skips them, and so do we.
    expects_panic: []bool,

    pub fn deinit(m: Metadata, gpa: Allocator) void {
        for (m.names) |n| gpa.free(n);
        gpa.free(m.names);
        gpa.free(m.expects_panic);
    }
};

/// Parses a `test_metadata` body.
pub fn parseMetadata(gpa: Allocator, body: []const u8) !Metadata {
    var r: Io.Reader = .fixed(body);
    const hdr = try r.takeStruct(InMessage.TestMetadata, .little);
    const name_offsets = try gpa.alloc(u32, hdr.tests_len);
    defer gpa.free(name_offsets);
    for (name_offsets) |*o| o.* = try r.takeInt(u32, .little);
    const expects_panic = try gpa.alloc(bool, hdr.tests_len);
    errdefer gpa.free(expects_panic);
    for (expects_panic) |*e| e.* = (try r.takeInt(u32, .little)) != 0;
    const strings = try r.take(hdr.string_bytes_len);

    const names = try gpa.alloc([]const u8, hdr.tests_len);
    var done: usize = 0;
    errdefer {
        for (names[0..done]) |n| gpa.free(n);
        gpa.free(names);
    }
    for (names, name_offsets) |*n, o| {
        if (o >= strings.len) return error.BadMetadata;
        n.* = try gpa.dupe(u8, std.mem.sliceTo(strings[o..], 0));
        done += 1;
    }
    return .{ .names = names, .expects_panic = expects_panic };
}

/// Parses a `test_results` body into a launcher status.
pub fn parseResults(body: []const u8) !struct { index: u32, status: sched.Status } {
    var r: Io.Reader = .fixed(body);
    const tr = try r.takeStruct(InMessage.TestResults, .little);
    const status: sched.Status = switch (tr.flags.status) {
        .fail => .fail,
        .skip => .skip,
        // A pass that leaked or logged errors fails, as in the build runner.
        .pass => if (tr.flags.leak_count > 0) .leak else if (tr.flags.log_err_count > 0) .log_err else .pass,
    };
    return .{ .index = tr.index, .status = status };
}

/// One child process and its pipes. Heap-allocated: the multi-reader keeps
/// pointers into it.
const Proc = struct {
    child: std.process.Child,
    mr_buf: Io.File.MultiReader.Buffer(2),
    mr: Io.File.MultiReader,
    stdin_writer: Io.File.Writer,
    client: std.zig.Client,
};

pub const Executor = struct {
    gpa: Allocator,
    io: Io,
    /// The child's argv: the test executable, `--listen=-`, `--seed=`.
    argv: []const []const u8,
    test_timeout_ns: u64,
    /// Tests declared slow (indexed by test index; shorter than the test
    /// count means "not slow"): their timeout is `slow_factor` times the
    /// default - Chromium's and V8's SLOW x4, WebKit's `Slow` expectation.
    slow: []const bool = &.{},
    slow_factor: u64 = 4,
    /// The build-wide cap on test processes (slots.zig), when set: each
    /// child holds a slot while it lives.
    slots: ?*Slots = null,
    procs: []?*Proc,
    held: []?Slots.Slot,
    /// Summed over every child: user + system CPU, and the largest peak RSS.
    cpu_ns: std.atomic.Value(u64) = .init(0),
    peak_rss: std.atomic.Value(u64) = .init(0),
    /// Children that exited non-zero after `exit` (Chromium marks such a
    /// batch TEST_FAILURE_ON_EXIT).
    exit_failures: std.atomic.Value(u32) = .init(0),

    pub fn init(gpa: Allocator, io: Io, argv: []const []const u8, test_timeout_ns: u64, jobs: u32) !Executor {
        const procs = try gpa.alloc(?*Proc, @max(jobs, 1));
        errdefer gpa.free(procs);
        @memset(procs, null);
        const held = try gpa.alloc(?Slots.Slot, procs.len);
        @memset(held, null);
        return .{ .gpa = gpa, .io = io, .argv = argv, .test_timeout_ns = test_timeout_ns, .procs = procs, .held = held };
    }

    /// Test `t`'s timeout.
    pub fn timeoutFor(e: *const Executor, t: u32) u64 {
        const slow = t < e.slow.len and e.slow[t];
        return if (slow) e.test_timeout_ns * e.slow_factor else e.test_timeout_ns;
    }

    pub fn deinit(e: *Executor) void {
        for (e.procs, 0..) |p, w| {
            if (p != null) _ = e.finish(@intCast(w), .kill);
        }
        e.gpa.free(e.procs);
        e.gpa.free(e.held);
    }

    pub fn executor(e: *Executor) sched.Executor {
        return .{ .ptr = e, .vtable = &.{ .start = start, .run = run, .stop = stop } };
    }

    fn start(ptr: *anyopaque, w: u32) anyerror!void {
        const e: *Executor = @ptrCast(@alignCast(ptr));
        std.debug.assert(e.procs[w] == null);
        if (e.slots) |slots| {
            std.debug.assert(e.held[w] == null);
            e.held[w] = try slots.acquire();
        }
        errdefer e.releaseSlot(w);
        const p = try e.gpa.create(Proc);
        errdefer e.gpa.destroy(p);
        p.child = try std.process.spawn(e.io, .{
            .argv = e.argv,
            .stdin = .pipe,
            .stdout = .pipe,
            .stderr = .pipe,
            .request_resource_usage_statistics = true,
        });
        p.mr.init(e.gpa, e.io, p.mr_buf.toStreams(), &.{ p.child.stdout.?, p.child.stderr.? });
        p.stdin_writer = p.child.stdin.?.writerStreaming(e.io, &.{});
        p.client = .{ .in = p.mr.reader(0), .out = &p.stdin_writer.interface };
        e.procs[w] = p;
    }

    fn releaseSlot(e: *Executor, w: u32) void {
        const slots = e.slots orelse return;
        const slot = e.held[w] orelse return;
        e.held[w] = null;
        slots.release(slot);
    }

    fn deadline(e: *Executor, from: Io.Clock.Timestamp, ns: u64) Io.Timeout {
        _ = e;
        return .{ .deadline = from.addDuration(.{ .clock = .awake, .raw = .fromNanoseconds(ns) }) };
    }

    fn run(ptr: *anyopaque, w: u32, t: u32) anyerror!sched.RunResult {
        const e: *Executor = @ptrCast(@alignCast(ptr));
        const io = e.io;
        const p = e.procs[w].?;
        // Waiting for the runner itself (test_started) gets at least 60 s,
        // as in the build runner (`response_timeout`).
        const test_ns = e.timeoutFor(t);
        const response_ns = @max(test_ns, 60 * std.time.ns_per_s);

        p.client.serveRunTest(t) catch return e.died(w, "could not send run_test (the process is gone)", 0);

        var began = Io.Clock.Timestamp.now(io, .awake);
        var timeout = e.deadline(began, response_ns);
        while (true) {
            const header = p.client.receiveMessageWithMultiReader(&p.mr, timeout) catch |err| switch (err) {
                error.Timeout => {
                    const ns = elapsed(io, began);
                    const out = try e.stderrSnapshot(p, "timed out", test_ns);
                    _ = e.finish(w, .kill);
                    return .{ .status = .timeout, .ns = ns, .output = out };
                },
                error.EndOfStream => return e.died(w, null, elapsed(io, began)),
                else => |x| {
                    _ = e.finish(w, .kill);
                    return x;
                },
            };
            const body = p.client.in.take(header.bytes_len) catch unreachable;
            switch (header.tag) {
                .test_started => {
                    began = Io.Clock.Timestamp.now(io, .awake);
                    timeout = e.deadline(began, test_ns);
                },
                .test_results => {
                    const res = try parseResults(body);
                    if (res.index != t) return error.ProtocolMismatch;
                    const ns = elapsed(io, began);
                    const stderr = p.mr.reader(1);
                    const out: []u8 = if (res.status.ok()) &.{} else try e.gpa.dupe(u8, stderr.buffered());
                    stderr.tossBuffered();
                    return .{ .status = res.status, .ns = ns, .output = out };
                },
                else => {}, // zig_version, and anything newer
            }
        }
    }

    fn stop(ptr: *anyopaque, w: u32) void {
        const e: *Executor = @ptrCast(@alignCast(ptr));
        if (e.procs[w] != null) _ = e.finish(w, .exit);
    }

    /// The process closed its pipes while a test ran: a crash. Collects what
    /// it printed and how it ended.
    fn died(e: *Executor, w: u32, why: ?[]const u8, ns: u64) !sched.RunResult {
        const p = e.procs[w].?;
        p.mr.fillRemaining(.{ .duration = .{ .clock = .awake, .raw = .fromSeconds(5) } }) catch {};
        const stderr = try e.gpa.dupe(u8, p.mr.reader(1).buffered());
        defer e.gpa.free(stderr);
        const term = e.finish(w, .wait);
        const out = try std.fmt.allocPrint(e.gpa, "launcher: test process {s}{f}\n{s}", .{
            if (why) |y| y else "",
            if (term) |tm| FmtTerm{ .term = tm } else FmtTerm{ .term = null },
            stderr,
        });
        return .{ .status = .crash, .ns = ns, .output = out };
    }

    fn stderrSnapshot(e: *Executor, p: *Proc, what: []const u8, ns: u64) ![]u8 {
        return std.fmt.allocPrint(e.gpa, "launcher: test {s} after {d} s\n{s}", .{
            what, ns / std.time.ns_per_s, p.mr.reader(1).buffered(),
        });
    }

    const Ending = enum { exit, wait, kill };

    /// Ends worker `w`'s process: `exit` asks it to exit and waits (killing
    /// it if it takes over 30 s), `wait` waits for a process already
    /// ending, `kill` kills it. Accounts its CPU and RSS.
    fn finish(e: *Executor, w: u32, how: Ending) ?std.process.Child.Term {
        const io = e.io;
        const p = e.procs[w] orelse return null;
        e.procs[w] = null;
        defer e.gpa.destroy(p);
        // After the process is gone (defers run last-in first-out).
        defer e.releaseSlot(w);

        var term: ?std.process.Child.Term = null;
        var kill = how == .kill;
        if (how == .exit) {
            p.client.serveBodylessMessage(.exit) catch {};
            p.mr.fillRemaining(.{ .duration = .{ .clock = .awake, .raw = .fromSeconds(30) } }) catch {
                kill = true;
            };
        }
        if (kill) {
            p.child.kill(io);
            p.mr.deinit();
        } else {
            if (p.child.stdin) |f| f.close(io);
            p.child.stdin = null;
            p.mr.deinit();
            term = p.child.wait(io) catch null;
            if (how == .exit) {
                if (term) |tm| if (!tm.success()) {
                    _ = e.exit_failures.fetchAdd(1, .monotonic);
                };
            }
        }
        e.account(&p.child);
        return term;
    }

    fn account(e: *Executor, child: *const std.process.Child) void {
        const ru = child.resource_usage_statistics.rusage orelse return;
        const us = tvUs(ru.utime) + tvUs(ru.stime);
        _ = e.cpu_ns.fetchAdd(us * std.time.ns_per_us, .monotonic);
        const rss: u64 = child.resource_usage_statistics.getMaxRss() orelse 0;
        _ = e.peak_rss.fetchMax(rss, .monotonic);
    }
};

fn tvUs(tv: anytype) u64 {
    return @as(u64, @intCast(tv.sec)) * std.time.us_per_s + @as(u64, @intCast(tv.usec));
}

fn elapsed(io: Io, from: Io.Clock.Timestamp) u64 {
    return @intCast(@max(from.untilNow(io).raw.nanoseconds, 0));
}

const FmtTerm = struct {
    term: ?std.process.Child.Term,
    pub fn format(f: FmtTerm, w: *Io.Writer) Io.Writer.Error!void {
        if (f.term) |t| return t.format(w);
        try w.writeAll("ended (status unknown)");
    }
};

/// Lists the tests of `argv[0]` without running any.
pub fn queryMetadata(gpa: Allocator, io: Io, argv: []const []const u8) !Metadata {
    var child = try std.process.spawn(io, .{ .argv = argv, .stdin = .pipe, .stdout = .pipe, .stderr = .inherit });
    var mr_buf: Io.File.MultiReader.Buffer(1) = undefined;
    var mr: Io.File.MultiReader = undefined;
    mr.init(gpa, io, mr_buf.toStreams(), &.{child.stdout.?});
    var stdin_writer = child.stdin.?.writerStreaming(io, &.{});
    var client: std.zig.Client = .{ .in = mr.reader(0), .out = &stdin_writer.interface };
    var ok = false;
    defer if (!ok) {
        child.kill(io);
        mr.deinit();
    };

    try client.serveBodylessMessage(.query_test_metadata);
    const timeout: Io.Timeout = .{ .duration = .{ .clock = .awake, .raw = .fromSeconds(120) } };
    const md = md: while (true) {
        const header = try client.receiveMessageWithMultiReader(&mr, timeout);
        const body = client.in.take(header.bytes_len) catch unreachable;
        if (header.tag == .test_metadata) break :md try parseMetadata(gpa, body);
    };
    errdefer md.deinit(gpa);
    client.serveBodylessMessage(.exit) catch {};
    mr.fillRemaining(timeout) catch {};
    if (child.stdin) |f| f.close(io);
    child.stdin = null;
    mr.deinit();
    ok = true;
    _ = child.wait(io) catch {};
    return md;
}

// ---------------------------------------------------------------------------

const testing = std.testing;

/// Frames a message the way the test runner does, with std.zig.Server, and
/// returns its body.
fn serverMessage(aw: *Io.Writer.Allocating, tag: InMessage.Tag) ![]const u8 {
    const all = aw.written();
    var r: Io.Reader = .fixed(all);
    const header = try r.takeStruct(InMessage.Header, .little);
    try testing.expectEqual(tag, header.tag);
    return try r.take(header.bytes_len);
}

test "parses the metadata std.zig.Server sends" {
    var aw: Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    var server: std.zig.Server = .{ .in = undefined, .out = &aw.writer };
    // "\0alpha\0sub.b_test.test.beta two\0"
    const strings = "\x00alpha\x00sub.b_test.test.beta two\x00";
    try server.serveTestMetadata(.{
        .names = &.{ 1, 7 },
        .expected_panic_msgs = &.{ 0, 1 },
        .string_bytes = strings,
    });
    const md = try parseMetadata(testing.allocator, try serverMessage(&aw, .test_metadata));
    defer md.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), md.names.len);
    try testing.expectEqualStrings("alpha", md.names[0]);
    try testing.expectEqualStrings("sub.b_test.test.beta two", md.names[1]);
    try testing.expectEqualSlices(bool, &.{ false, true }, md.expects_panic);
}

test "a test declared slow gets the slow factor times the timeout" {
    var e = try Executor.init(testing.allocator, testing.io, &.{"x"}, 10 * std.time.ns_per_s, 1);
    defer e.deinit();
    const slow = [_]bool{ false, true };
    e.slow = &slow;
    try testing.expectEqual(10 * std.time.ns_per_s, e.timeoutFor(0));
    try testing.expectEqual(40 * std.time.ns_per_s, e.timeoutFor(1));
    // Past the end of the list: not slow.
    try testing.expectEqual(10 * std.time.ns_per_s, e.timeoutFor(7));
    e.slow_factor = 8;
    try testing.expectEqual(80 * std.time.ns_per_s, e.timeoutFor(1));
}

test "a truncated metadata body is an error, not a crash" {
    try testing.expectError(error.EndOfStream, parseMetadata(testing.allocator, "\x05\x00"));
}

test "parses test results: status, and a pass that leaked or logged errors fails" {
    const cases = [_]struct { flags: InMessage.TestResults.Flags, want: sched.Status }{
        .{ .flags = .{ .status = .pass, .fuzz = false, .log_err_count = 0, .leak_count = 0 }, .want = .pass },
        .{ .flags = .{ .status = .fail, .fuzz = false, .log_err_count = 0, .leak_count = 0 }, .want = .fail },
        .{ .flags = .{ .status = .skip, .fuzz = false, .log_err_count = 0, .leak_count = 0 }, .want = .skip },
        .{ .flags = .{ .status = .pass, .fuzz = false, .log_err_count = 0, .leak_count = 3 }, .want = .leak },
        .{ .flags = .{ .status = .pass, .fuzz = false, .log_err_count = 2, .leak_count = 0 }, .want = .log_err },
    };
    for (cases, 0..) |c, i| {
        var aw: Io.Writer.Allocating = .init(testing.allocator);
        defer aw.deinit();
        var server: std.zig.Server = .{ .in = undefined, .out = &aw.writer };
        try server.serveTestResults(.{ .index = @intCast(i), .flags = c.flags });
        const res = try parseResults(try serverMessage(&aw, .test_results));
        try testing.expectEqual(@as(u32, @intCast(i)), res.index);
        try testing.expectEqual(c.want, res.status);
    }
}

test "real processes: each kind of result, a crash and a timeout blamed and restarted, an order dependence classified" {
    // build.zig compiles tools/test_launcher/fixture_test.zig and passes its path.
    const fixture = @import("launcher_fixture");
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ fixture.path, "--listen=-", "--seed=0x1" };

    const md = try queryMetadata(gpa, io, &argv);
    defer md.deinit(gpa);
    const names = [_][]const u8{ "passes", "fails", "crashes", "hangs", "leaks", "poisons", "needs a clean process", "skips" };
    try testing.expectEqual(names.len, md.names.len);
    var all: [names.len]u32 = undefined;
    for (names, 0..) |want, i| {
        try testing.expect(std.mem.endsWith(u8, md.names[i], want));
        all[i] = @intCast(i);
    }

    const plan_mod = @import("plan.zig");
    var plan = try plan_mod.make(gpa, &all, .{ .seed = 1, .shuffle = false, .batch_size = 0 });
    defer plan.deinit(gpa);
    var exec = try Executor.init(gpa, io, &argv, 2 * std.time.ns_per_s, 1);
    defer exec.deinit();
    var run = try sched.Run.init(gpa, io, &plan, md.names.len, exec.executor(), .{ .jobs = 1, .alone_runs = 1 });
    defer run.deinit();
    try run.execute();

    const want = [_]struct { first: sched.Status, verdict: sched.Verdict }{
        .{ .first = .pass, .verdict = .pass },
        .{ .first = .fail, .verdict = .fail },
        .{ .first = .crash, .verdict = .fail },
        .{ .first = .timeout, .verdict = .fail },
        .{ .first = .leak, .verdict = .fail },
        .{ .first = .pass, .verdict = .pass },
        .{ .first = .fail, .verdict = .order_dependent },
        .{ .first = .skip, .verdict = .skip },
    };
    for (want, 0..) |w, i| {
        errdefer std.debug.print("test {s}: first {t}, verdict {t}\n", .{ names[i], run.records[i].first, run.records[i].verdict });
        try testing.expectEqual(w.first, run.records[i].first);
        try testing.expectEqual(w.verdict, run.records[i].verdict);
    }
    // The crash report names the panic.
    try testing.expect(std.mem.indexOf(u8, run.records[2].output, "the fixture crashes here") != null);
    // One batch process, a restart after the crash and after the timeout;
    // then one alone run each for the five failures; then the replay of
    // "needs a clean process" after the tests that shared its process -
    // "leaks" and "poisons", from where the restart after the timeout began.
    try testing.expectEqual(@as(u32, 3 + 5 + 1), run.processes.load(.monotonic));
    try testing.expectEqual(@as(u32, 4), run.records[6].process_start);
    try testing.expectEqual(@as(u32, 0), exec.exit_failures.load(.monotonic));
    try testing.expect(exec.cpu_ns.load(.monotonic) > 0);
}
