//! Server mode (`--listen=-`): the launcher as `zig build test` sees it.
//!
//! The build runner runs a test executable by speaking the Zig test-runner
//! protocol to it (compiler/Maker/Step/Run.zig evalZigTest): it asks for the
//! test list, then sends `run_test <index>` for each test in index order and
//! reads `test_started` and `test_results`. In server mode the launcher
//! answers that protocol in place of the test executable: it lists the
//! executable's tests, runs them all through the scheduler (seeded batches in
//! parallel child processes, every failure re-run alone and classified), and
//! answers each `run_test` with that test's verdict as soon as it is known.
//!
//! So the build runner keeps everything it does for a test executable: one
//! Build Summary with the test counts, an `error: '<test>' failed:` line for
//! each test that did not pass (with the launcher's verdict block as its
//! text - gate scripts grep that line), and the cache: a `zig_test` Run step
//! has no side effects, so an unchanged executable is not run again.
//! FAIL, ORDER-DEPENDENT and FLAKY are all reported as failures - none is a
//! pass (Crane's one-flake-then-bug rule).
//!
//! LAUNCHER-ERROR is not the test's failure, so it is not reported as one:
//! the test did not run, and the build runner hears `skip` for it. The
//! launcher then fails the step itself - it exits non-zero after `exit`,
//! having printed what could not be done (`report.writeLauncherErrors`) -
//! so the build runner reports the step failed, with that text, and no test
//! is blamed (lane tlfix1: a failed process start had come out as
//! `error: '<test>' failed:` FLAKY for each test of its batch).

const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const sched = @import("scheduler.zig");
const report = @import("report.zig");
const TestResults = std.zig.Server.Message.TestResults;

/// One server-mode run: the executable's tests and the scheduler run that
/// answers for them. The caller builds the `sched.Run` (not yet executed)
/// with `onVerdict` and the session as its `on_verdict` callback.
pub const Session = struct {
    io: Io,
    names: []const []const u8,
    expects_panic: []const bool,
    /// Whether each test index is in the plan (the rest answer `skip`).
    selected: []const bool,
    run: *sched.Run,
    seed: u64,
    /// Set as each test's verdict becomes known.
    known: []Io.Event,
    future: ?Io.Future(void) = null,
    run_error: ?anyerror = null,
    /// `--report-only`: a suite whose findings in a variant are not fixed yet
    /// (build.zig `suite_configs`, a TEMPORARY row). Every verdict is still
    /// printed and written to the result file, but the build runner hears
    /// `pass` for what failed - the variant's report mode, as the Crane test
    /// runner's report-only state check logs without failing.
    report_only: bool = false,
    /// A filtered run (`--filter`): the tests the build runner hears of, in
    /// order - entry k is the test of the metadata's index k and of
    /// `run_test k`. The others are not listed at all, so its Build Summary
    /// counts the selected tests, and a run that selects none lists none.
    /// Null: every test.
    listed: ?[]const u32 = null,

    pub fn init(gpa: Allocator, io: Io, names: []const []const u8, expects_panic: []const bool, selected: []const bool, run: *sched.Run, seed: u64) !Session {
        const known = try gpa.alloc(Io.Event, names.len);
        @memset(known, .unset);
        return .{ .io = io, .names = names, .expects_panic = expects_panic, .selected = selected, .run = run, .seed = seed, .known = known };
    }

    pub fn deinit(s: *Session, gpa: Allocator) void {
        if (s.future) |*f| f.cancel(s.io);
        gpa.free(s.known);
    }

    /// The scheduler's `on_verdict` callback (ctx = the session).
    pub fn onVerdict(ctx: ?*anyopaque, t: u32, _: *const sched.TestRecord) void {
        const s: *Session = @ptrCast(@alignCast(ctx.?));
        s.known[t].set(s.io);
    }

    fn runAll(s: *Session) void {
        s.run.execute() catch |err| {
            s.run_error = err;
        };
        // Whatever happened, nobody may wait forever: a test without a
        // verdict reads NOT-RUN, which is a failure.
        for (s.known) |*e| e.set(s.io);
    }

    fn start(s: *Session) !void {
        if (s.future != null) return;
        s.future = s.io.concurrent(runAll, .{s}) catch |err| switch (err) {
            // No second thread: run everything now, then answer.
            error.ConcurrencyUnavailable => blk: {
                s.runAll();
                break :blk null;
            },
        };
    }

    /// Blocks until test `t` has a verdict. Starts the run on first use.
    fn verdictOf(s: *Session, t: u32) !sched.Verdict {
        if (!s.selected[t]) return .skip;
        try s.start();
        try s.known[t].wait(s.io);
        return s.run.records[t].verdict;
    }

    /// Waits for the whole run (every answered test is done; this collects
    /// the scheduler's thread).
    pub fn finish(s: *Session) void {
        if (s.future) |*f| {
            f.await(s.io);
            s.future = null;
        }
    }
};

/// The build runner's status for a verdict: only PASS passes; SKIP and
/// LAUNCHER-ERROR (the test did not run - the launcher fails the step for
/// it instead, `main.exitStatus`) skip.
pub fn statusOf(v: sched.Verdict) TestResults.Status {
    return switch (v) {
        .pass => .pass,
        .skip, .launcher_error => .skip,
        .fail, .order_dependent, .flaky, .not_run => .fail,
    };
}

/// What the build runner hears for a verdict: `statusOf`, except that in
/// report-only mode a failure is reported (printed, written) and answered
/// `pass`.
pub fn answerOf(v: sched.Verdict, report_only: bool) TestResults.Status {
    const status = statusOf(v);
    return if (report_only and status == .fail) .pass else status;
}

/// Answers the protocol on `in`/`out` until the build runner sends `exit`
/// (or closes the pipe). `diag` is the launcher's stderr: a failing test's
/// verdict block goes there, flushed, just before its `test_results`, so the
/// build runner prints it under that test's name - as it does with what a
/// failing test writes to stderr.
pub fn serve(s: *Session, gpa: Allocator, in: *Io.Reader, out: *Io.Writer, diag: *Io.Writer) !void {
    var server: std.zig.Server = .{ .in = in, .out = out };
    try server.serveStringMessage(.zig_version, builtin.zig_version_string);
    while (true) {
        const hdr = server.receiveMessage() catch |err| switch (err) {
            error.EndOfStream => return,
            else => |e| return e,
        };
        switch (hdr.tag) {
            .exit => return,
            .query_test_metadata => try serveMetadata(&server, gpa, s.names, s.expects_panic, s.listed),
            .run_test => {
                // The build runner's index: into the listing, when filtered.
                const k = try server.receiveBody_u32();
                const t = if (s.listed) |l| (if (k < l.len) l[k] else return error.NoSuchTest) else k;
                if (t >= s.names.len) return error.NoSuchTest;
                try server.serveStringMessage(.test_started, &.{});
                const verdict = try s.verdictOf(t);
                const status = answerOf(verdict, s.report_only);
                // A LAUNCHER-ERROR prints once for the run, not per test.
                if (statusOf(verdict) == .fail) {
                    if (s.report_only) try diag.writeAll("report-only: ");
                    try report.writeVerdictBlock(diag, s.names[t], &s.run.records[t], s.seed);
                    try diag.flush();
                    // The build runner reads stderr and the protocol as two
                    // streams and files what stderr holds when `test_results`
                    // arrives under that test; a block still in the pipe
                    // would land under the next failure, or at the end. A
                    // moment for it to arrive (failures only - rare).
                    s.io.sleep(.fromMilliseconds(100), .awake) catch {};
                }
                try server.serveTestResults(.{ .index = k, .flags = .{
                    .status = status,
                    .fuzz = false,
                    .log_err_count = 0,
                    .leak_count = 0,
                } });
            },
            else => try in.discardAll(hdr.bytes_len),
        }
    }
}

/// The executable's test list, as its own test runner would send it - or,
/// filtered, the tests `listed` names, in its order; a test that expects a
/// panic is marked so the build runner skips it, as it skips it in the
/// executable itself.
fn serveMetadata(server: *std.zig.Server, gpa: Allocator, names: []const []const u8, expects_panic: []const bool, listed: ?[]const u32) !void {
    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(gpa);
    try strings.append(gpa, 0);
    const len = if (listed) |l| l.len else names.len;
    const offsets = try gpa.alloc(u32, len);
    defer gpa.free(offsets);
    const panics = try gpa.alloc(u32, len);
    defer gpa.free(panics);
    for (offsets, panics, 0..) |*o, *pm, k| {
        const t = if (listed) |l| l[k] else k;
        o.* = @intCast(strings.items.len);
        try strings.appendSlice(gpa, names[t]);
        try strings.append(gpa, 0);
        // Any non-zero offset says "expects a panic"; point it at the name.
        pm.* = if (expects_panic[t]) o.* else 0;
    }
    try server.serveTestMetadata(.{ .names = offsets, .expected_panic_msgs = panics, .string_bytes = strings.items });
}

// ---------------------------------------------------------------------------

const testing = std.testing;
const plan_mod = @import("plan.zig");
const child_mod = @import("child.zig");

/// A fake executor: test 1 always fails, test 2 fails once (a flake), the
/// rest pass.
const Fake = struct {
    attempts: [8]std.atomic.Value(u32) = @splat(.init(0)),

    fn executor(f: *Fake) sched.Executor {
        return .{ .ptr = f, .vtable = &.{ .start = start, .run = run, .stop = stop } };
    }
    fn start(_: *anyopaque, _: u32, _: []const u32, _: *Io.Writer) anyerror!void {}
    fn stop(_: *anyopaque, _: u32) void {}
    fn run(ptr: *anyopaque, _: u32, t: u32) anyerror!sched.RunResult {
        const f: *Fake = @ptrCast(@alignCast(ptr));
        const attempt = f.attempts[t].fetchAdd(1, .monotonic);
        const status: sched.Status = if (t == 1 or (t == 2 and attempt == 0)) .fail else .pass;
        const out: []u8 = if (status.ok()) &.{} else try std.fmt.allocPrint(testing.allocator, "test {d} said no\n", .{t});
        return .{ .status = status, .ns = 1000, .output = out };
    }
};

test "serves the build runner: the list, then each test's verdict, failures with their block" {
    const gpa = testing.allocator;
    const io = testing.io;
    const names = [_][]const u8{ "a.test.zero", "a.test.one", "a.test.two", "a.test.three", "a.test.panics" };
    const expects_panic = [_]bool{ false, false, false, false, true };
    const selected = [_]bool{ true, true, true, true, false };

    var plan = try plan_mod.make(gpa, &.{ 0, 1, 2, 3 }, .{ .seed = 1, .shuffle = false, .batch_size = 2 });
    defer plan.deinit(gpa);
    var fake: Fake = .{};
    var session: Session = undefined;
    var run = try sched.Run.init(gpa, io, &plan, names.len, fake.executor(), .{
        .jobs = 2,
        .alone_runs = 2,
        .on_verdict = Session.onVerdict,
        .on_verdict_ctx = &session,
    });
    defer run.deinit();
    session = try Session.init(gpa, io, &names, &expects_panic, &selected, &run, 0xabc);
    defer session.deinit(gpa);

    // What the build runner sends: the list, run_test for each test it does
    // not skip (index order), exit.
    var to_server: Io.Writer.Allocating = .init(gpa);
    defer to_server.deinit();
    var client: std.zig.Client = .{ .in = undefined, .out = &to_server.writer };
    try client.serveBodylessMessage(.query_test_metadata);
    for ([_]u32{ 0, 1, 2, 3 }) |t| try client.serveRunTest(t);
    try client.serveBodylessMessage(.exit);

    var in: Io.Reader = .fixed(to_server.written());
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    var diag: Io.Writer.Allocating = .init(gpa);
    defer diag.deinit();
    try serve(&session, gpa, &in, &out.writer, &diag.writer);
    session.finish();

    // Read the answers as the build runner does.
    var r: Io.Reader = .fixed(out.written());
    const Msg = std.zig.Server.Message;
    var hdr = try r.takeStruct(Msg.Header, .little);
    try testing.expectEqual(Msg.Tag.zig_version, hdr.tag);
    r.toss(hdr.bytes_len);
    hdr = try r.takeStruct(Msg.Header, .little);
    try testing.expectEqual(Msg.Tag.test_metadata, hdr.tag);
    const md = try child_mod.parseMetadata(gpa, try r.take(hdr.bytes_len));
    defer md.deinit(gpa);
    try testing.expectEqual(@as(usize, 5), md.names.len);
    try testing.expectEqualStrings("a.test.two", md.names[2]);
    try testing.expectEqualSlices(bool, &expects_panic, md.expects_panic);

    const want = [_]TestResults.Status{ .pass, .fail, .fail, .pass };
    for (want, 0..) |w, t| {
        hdr = try r.takeStruct(Msg.Header, .little);
        try testing.expectEqual(Msg.Tag.test_started, hdr.tag);
        r.toss(hdr.bytes_len);
        hdr = try r.takeStruct(Msg.Header, .little);
        try testing.expectEqual(Msg.Tag.test_results, hdr.tag);
        const res = try r.takeStruct(TestResults, .little);
        try testing.expectEqual(@as(u32, @intCast(t)), res.index);
        try testing.expectEqual(w, res.flags.status);
    }
    try testing.expectEqual(@as(usize, 0), r.bufferedLen());

    // The failure blocks name the verdict, the test and the seed, in
    // answer order.
    const text = diag.written();
    const one = std.mem.indexOf(u8, text, "FAIL a.test.one").?;
    const two = std.mem.indexOf(u8, text, "FLAKY a.test.two").?;
    try testing.expect(one < two);
    try testing.expect(std.mem.indexOf(u8, text, "seed 0xabc") != null);
    try testing.expect(std.mem.indexOf(u8, text, "test 1 said no") != null);
}

test "a filtered session lists only its tests, and answers each run_test for the test the listing names" {
    const gpa = testing.allocator;
    const io = testing.io;
    const names = [_][]const u8{ "a.test.zero", "a.test.one", "a.test.two", "b.test.zero", "a.test.panics" };
    const expects_panic = [_]bool{ false, false, false, false, true };
    // The filter took tests 1, 2 and 4 (the panicking one is listed, as an
    // unfiltered run lists it, and the build runner skips it).
    const listed = [_]u32{ 1, 2, 4 };
    const selected = [_]bool{ false, true, true, false, false };
    var plan = try plan_mod.make(gpa, &.{ 1, 2 }, .{ .seed = 1, .shuffle = false, .batch_size = 0 });
    defer plan.deinit(gpa);
    var fake: Fake = .{};
    var session: Session = undefined;
    var run = try sched.Run.init(gpa, io, &plan, names.len, fake.executor(), .{
        .jobs = 1,
        .alone_runs = 2,
        .on_verdict = Session.onVerdict,
        .on_verdict_ctx = &session,
    });
    defer run.deinit();
    session = try Session.init(gpa, io, &names, &expects_panic, &selected, &run, 0xabc);
    session.listed = &listed;
    defer session.deinit(gpa);

    var to_server: Io.Writer.Allocating = .init(gpa);
    defer to_server.deinit();
    var client: std.zig.Client = .{ .in = undefined, .out = &to_server.writer };
    try client.serveBodylessMessage(.query_test_metadata);
    for ([_]u32{ 0, 1 }) |k| try client.serveRunTest(k);
    try client.serveBodylessMessage(.exit);
    var in: Io.Reader = .fixed(to_server.written());
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    var diag: Io.Writer.Allocating = .init(gpa);
    defer diag.deinit();
    try serve(&session, gpa, &in, &out.writer, &diag.writer);
    session.finish();

    var r: Io.Reader = .fixed(out.written());
    const Msg = std.zig.Server.Message;
    var hdr = try r.takeStruct(Msg.Header, .little);
    r.toss(hdr.bytes_len); // zig_version
    hdr = try r.takeStruct(Msg.Header, .little);
    try testing.expectEqual(Msg.Tag.test_metadata, hdr.tag);
    const md = try child_mod.parseMetadata(gpa, try r.take(hdr.bytes_len));
    defer md.deinit(gpa);
    try testing.expectEqual(@as(usize, 3), md.names.len);
    try testing.expectEqualStrings("a.test.one", md.names[0]);
    try testing.expectEqualStrings("a.test.two", md.names[1]);
    try testing.expectEqualStrings("a.test.panics", md.names[2]);
    try testing.expectEqualSlices(bool, &.{ false, false, true }, md.expects_panic);
    // run_test 0 is a.test.one (always fails), 1 is a.test.two (a flake).
    for ([_]TestResults.Status{ .fail, .fail }, 0..) |w, k| {
        hdr = try r.takeStruct(Msg.Header, .little);
        try testing.expectEqual(Msg.Tag.test_started, hdr.tag);
        r.toss(hdr.bytes_len);
        hdr = try r.takeStruct(Msg.Header, .little);
        const res = try r.takeStruct(TestResults, .little);
        try testing.expectEqual(@as(u32, @intCast(k)), res.index);
        try testing.expectEqual(w, res.flags.status);
    }
    try testing.expectEqual(@as(usize, 0), r.bufferedLen());
    const text = diag.written();
    try testing.expect(std.mem.indexOf(u8, text, "FAIL a.test.one") != null);
    try testing.expect(std.mem.indexOf(u8, text, "FLAKY a.test.two") != null);
}

test "a filtered session that selected nothing lists no test" {
    const gpa = testing.allocator;
    const io = testing.io;
    const names = [_][]const u8{ "a.test.zero", "a.test.one" };
    const expects_panic = [_]bool{ false, false };
    const selected = [_]bool{ false, false };
    var plan = try plan_mod.make(gpa, &.{}, .{ .seed = 1, .shuffle = false, .batch_size = 10 });
    defer plan.deinit(gpa);
    var fake: Fake = .{};
    var session: Session = undefined;
    var run = try sched.Run.init(gpa, io, &plan, names.len, fake.executor(), .{
        .jobs = 1,
        .on_verdict = Session.onVerdict,
        .on_verdict_ctx = &session,
    });
    defer run.deinit();
    session = try Session.init(gpa, io, &names, &expects_panic, &selected, &run, 0xabc);
    session.listed = &.{};
    defer session.deinit(gpa);

    var to_server: Io.Writer.Allocating = .init(gpa);
    defer to_server.deinit();
    var client: std.zig.Client = .{ .in = undefined, .out = &to_server.writer };
    try client.serveBodylessMessage(.query_test_metadata);
    try client.serveBodylessMessage(.exit);
    var in: Io.Reader = .fixed(to_server.written());
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    var diag: Io.Writer.Allocating = .init(gpa);
    defer diag.deinit();
    try serve(&session, gpa, &in, &out.writer, &diag.writer);
    session.finish();

    var r: Io.Reader = .fixed(out.written());
    const Msg = std.zig.Server.Message;
    var hdr = try r.takeStruct(Msg.Header, .little);
    r.toss(hdr.bytes_len); // zig_version
    hdr = try r.takeStruct(Msg.Header, .little);
    try testing.expectEqual(Msg.Tag.test_metadata, hdr.tag);
    const md = try child_mod.parseMetadata(gpa, try r.take(hdr.bytes_len));
    defer md.deinit(gpa);
    try testing.expectEqual(@as(usize, 0), md.names.len);
    try testing.expectEqual(@as(usize, 0), r.bufferedLen());
    try testing.expectEqual(@as(u32, 0), run.processes.load(.monotonic));
}

test "report-only: every failure is printed, marked report-only, and answered pass; LAUNCHER-ERROR still skips" {
    try testing.expectEqual(TestResults.Status.pass, answerOf(.fail, true));
    try testing.expectEqual(TestResults.Status.pass, answerOf(.flaky, true));
    try testing.expectEqual(TestResults.Status.pass, answerOf(.order_dependent, true));
    try testing.expectEqual(TestResults.Status.skip, answerOf(.launcher_error, true));
    try testing.expectEqual(TestResults.Status.skip, answerOf(.skip, true));
    try testing.expectEqual(TestResults.Status.fail, answerOf(.fail, false));

    const gpa = testing.allocator;
    const io = testing.io;
    const names = [_][]const u8{ "a.test.zero", "a.test.one", "a.test.two" };
    const expects_panic = [_]bool{ false, false, false };
    const selected = [_]bool{ true, true, true };
    var plan = try plan_mod.make(gpa, &.{ 0, 1, 2 }, .{ .seed = 1, .shuffle = false, .batch_size = 0 });
    defer plan.deinit(gpa);
    var fake: Fake = .{};
    var session: Session = undefined;
    var run = try sched.Run.init(gpa, io, &plan, names.len, fake.executor(), .{
        .jobs = 1,
        .alone_runs = 2,
        .on_verdict = Session.onVerdict,
        .on_verdict_ctx = &session,
    });
    defer run.deinit();
    session = try Session.init(gpa, io, &names, &expects_panic, &selected, &run, 0xabc);
    session.report_only = true;
    defer session.deinit(gpa);

    var to_server: Io.Writer.Allocating = .init(gpa);
    defer to_server.deinit();
    var client: std.zig.Client = .{ .in = undefined, .out = &to_server.writer };
    for ([_]u32{ 0, 1, 2 }) |t| try client.serveRunTest(t);
    try client.serveBodylessMessage(.exit);
    var in: Io.Reader = .fixed(to_server.written());
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    var diag: Io.Writer.Allocating = .init(gpa);
    defer diag.deinit();
    try serve(&session, gpa, &in, &out.writer, &diag.writer);
    session.finish();

    var r: Io.Reader = .fixed(out.written());
    const Msg = std.zig.Server.Message;
    var hdr = try r.takeStruct(Msg.Header, .little);
    r.toss(hdr.bytes_len); // zig_version
    for (0..3) |t| {
        hdr = try r.takeStruct(Msg.Header, .little);
        r.toss(hdr.bytes_len); // test_started
        hdr = try r.takeStruct(Msg.Header, .little);
        const res = try r.takeStruct(TestResults, .little);
        try testing.expectEqual(@as(u32, @intCast(t)), res.index);
        try testing.expectEqual(TestResults.Status.pass, res.flags.status);
    }
    // The verdicts stand, and are printed as report-only.
    try testing.expectEqual(sched.Verdict.fail, run.records[1].verdict);
    try testing.expectEqual(sched.Verdict.flaky, run.records[2].verdict);
    const text = diag.written();
    try testing.expect(std.mem.indexOf(u8, text, "report-only: FAIL a.test.one") != null);
    try testing.expect(std.mem.indexOf(u8, text, "report-only: FLAKY a.test.two") != null);
}

test "statusOf: only PASS passes; SKIP and LAUNCHER-ERROR skip" {
    try testing.expectEqual(TestResults.Status.pass, statusOf(.pass));
    try testing.expectEqual(TestResults.Status.skip, statusOf(.skip));
    try testing.expectEqual(TestResults.Status.fail, statusOf(.fail));
    try testing.expectEqual(TestResults.Status.fail, statusOf(.order_dependent));
    try testing.expectEqual(TestResults.Status.fail, statusOf(.flaky));
    try testing.expectEqual(TestResults.Status.fail, statusOf(.not_run));
    // Not the test's failure: the launcher fails the step for it.
    try testing.expectEqual(TestResults.Status.skip, statusOf(.launcher_error));
}

/// An executor whose processes never start: the launcher failing, not the
/// tests.
const NoStart = struct {
    fn executor(n: *NoStart) sched.Executor {
        return .{ .ptr = n, .vtable = &.{ .start = start, .run = run, .stop = stop } };
    }
    fn start(_: *anyopaque, _: u32, _: []const u32, diag: *Io.Writer) anyerror!void {
        try diag.writeAll("no slot");
        return error.FileNotFound;
    }
    fn run(_: *anyopaque, _: u32, _: u32) anyerror!sched.RunResult {
        unreachable; // never started
    }
    fn stop(_: *anyopaque, _: u32) void {}
};

test "a test the launcher could not run is answered skip, with no failure block: no test is blamed" {
    const gpa = testing.allocator;
    const io = testing.io;
    const names = [_][]const u8{ "a.test.zero", "a.test.one" };
    const expects_panic = [_]bool{ false, false };
    const selected = [_]bool{ true, true };
    var plan = try plan_mod.make(gpa, &.{ 0, 1 }, .{ .seed = 1, .shuffle = false, .batch_size = 0 });
    defer plan.deinit(gpa);
    var no_start: NoStart = .{};
    var session: Session = undefined;
    var run = try sched.Run.init(gpa, io, &plan, names.len, no_start.executor(), .{
        .jobs = 1,
        .on_verdict = Session.onVerdict,
        .on_verdict_ctx = &session,
    });
    defer run.deinit();
    session = try Session.init(gpa, io, &names, &expects_panic, &selected, &run, 0x1);
    defer session.deinit(gpa);

    var to_server: Io.Writer.Allocating = .init(gpa);
    defer to_server.deinit();
    var client: std.zig.Client = .{ .in = undefined, .out = &to_server.writer };
    for ([_]u32{ 0, 1 }) |t| try client.serveRunTest(t);
    try client.serveBodylessMessage(.exit);
    var in: Io.Reader = .fixed(to_server.written());
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    var diag: Io.Writer.Allocating = .init(gpa);
    defer diag.deinit();
    try serve(&session, gpa, &in, &out.writer, &diag.writer);
    session.finish();

    var r: Io.Reader = .fixed(out.written());
    const Msg = std.zig.Server.Message;
    var hdr = try r.takeStruct(Msg.Header, .little);
    r.toss(hdr.bytes_len); // zig_version
    for (0..2) |t| {
        hdr = try r.takeStruct(Msg.Header, .little);
        r.toss(hdr.bytes_len); // test_started
        hdr = try r.takeStruct(Msg.Header, .little);
        try testing.expectEqual(Msg.Tag.test_results, hdr.tag);
        const res = try r.takeStruct(TestResults, .little);
        try testing.expectEqual(@as(u32, @intCast(t)), res.index);
        try testing.expectEqual(TestResults.Status.skip, res.flags.status);
    }
    try testing.expectEqual(@as(usize, 0), diag.written().len);
    try testing.expectEqual(@as(u32, 2), run.counts().launcher_error);
    try testing.expectEqualStrings("launcher: could not start the test process: no slot\n", run.records[0].cause);
}
