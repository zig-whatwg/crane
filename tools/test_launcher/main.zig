//! Crane's test launcher: runs ONE compiled Zig test executable as many
//! child processes, in seeded batches, and classifies every failure.
//!
//!   test_launcher <test-exe> [--jobs=N] [--batch=B] [--seed=S] [--no-shuffle]
//!                 [--timeout=SECONDS] [--alone-runs=R] [--only-batch=K]
//!                 [--filter=SUBSTRING] [--out=FILE.jsonl] [--list]
//!
//! `zig build test-launch -Dspec=<dir>` builds the suite's test executable
//! (the one `zig build test` runs) and runs this on it.
//!
//! Why, and from whom (tmp/plans/test-architecture-recommendation.md):
//! Chromium's base/test/launcher (10 tests per child process, 1 for browser
//! tests, one job per core, a failed test retried alone), V8's run-tests.py
//! (one seed per run, passed to every test, reruns with the same seed) and
//! WebKit's api-tests runner (restart after a crash, blame the test). Unlike
//! WebKit's and Gecko's shuffles, ours is seeded and printed, so a failure
//! replays; unlike all of them, a test that passes only on retry is not a
//! pass.
//!
//! Batch size 1 gives per-test process isolation from the same binary that
//! `-Dtest-isolation=file` compiled 1,592 times; batch 0 runs the whole suite
//! in one process.

const std = @import("std");
const Io = std.Io;
const plan_mod = @import("plan.zig");
const sched = @import("scheduler.zig");
const child_mod = @import("child.zig");
const report = @import("report.zig");

test {
    _ = plan_mod;
    _ = sched;
    _ = child_mod;
    _ = report;
    _ = Args;
    // Analyse main, so `zig build test` catches what only the executable uses.
    _ = &main;
}

const Args = struct {
    exe: ?[]const u8 = null,
    jobs: ?u32 = null,
    batch: u32 = 10,
    seed: ?u64 = null,
    shuffle: bool = true,
    timeout_s: u32 = 60,
    alone_runs: u8 = 2,
    only_batch: ?u32 = null,
    filter: ?[]const u8 = null,
    out: ?[]const u8 = null,
    list: bool = false,

    fn parse(args: []const []const u8) !Args {
        var a: Args = .{};
        for (args) |arg| {
            if (value(arg, "--jobs=")) |v| {
                a.jobs = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--batch=")) |v| {
                a.batch = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--seed=")) |v| {
                a.seed = try plan_mod.parseSeed(v);
            } else if (std.mem.eql(u8, arg, "--no-shuffle")) {
                a.shuffle = false;
            } else if (value(arg, "--timeout=")) |v| {
                a.timeout_s = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--alone-runs=")) |v| {
                a.alone_runs = @min(try std.fmt.parseUnsigned(u8, v, 10), sched.max_alone_runs);
            } else if (value(arg, "--only-batch=")) |v| {
                a.only_batch = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--filter=")) |v| {
                a.filter = v;
            } else if (value(arg, "--out=")) |v| {
                a.out = v;
            } else if (std.mem.eql(u8, arg, "--list")) {
                a.list = true;
            } else if (std.mem.startsWith(u8, arg, "--")) {
                return error.UnknownOption;
            } else if (a.exe == null) {
                a.exe = arg;
            } else return error.UnexpectedArgument;
        }
        if (a.exe == null) return error.MissingExecutable;
        return a;
    }

    fn value(arg: []const u8, comptime prefix: []const u8) ?[]const u8 {
        return if (std.mem.startsWith(u8, arg, prefix)) arg[prefix.len..] else null;
    }
};

const usage =
    \\usage: test_launcher <test-exe> [--jobs=N] [--batch=B] [--seed=S] [--no-shuffle]
    \\                     [--timeout=SECONDS] [--alone-runs=R] [--only-batch=K]
    \\                     [--filter=SUBSTRING] [--out=FILE.jsonl] [--list]
    \\  --batch=B       tests per child process (default 10; 1 = per-test isolation; 0 = the whole suite)
    \\  --jobs=N        child processes at once (default: the CPU count)
    \\  --seed=S        the run's seed, decimal or 0x hex (default: random, printed)
    \\  --no-shuffle    index order, as `zig build test` runs (batches still apply)
    \\  --timeout=S     per-test timeout in seconds (default 60)
    \\  --alone-runs=R  re-runs of each failed test alone (default 2)
    \\  --only-batch=K  run only batch K of the plan the seed and batch size make
    \\  --filter=TEXT   only tests whose name contains TEXT (selected at run time)
    \\  --out=FILE      the result file, one JSON line per test
    \\
;

test "args: options, defaults, and errors" {
    const a = try Args.parse(&.{ "zig-out/x", "--jobs=4", "--batch=1", "--seed=0x10", "--no-shuffle", "--timeout=5", "--alone-runs=3", "--only-batch=2", "--filter=css", "--out=o.jsonl" });
    try std.testing.expectEqualStrings("zig-out/x", a.exe.?);
    try std.testing.expectEqual(@as(?u32, 4), a.jobs);
    try std.testing.expectEqual(@as(u32, 1), a.batch);
    try std.testing.expectEqual(@as(?u64, 16), a.seed);
    try std.testing.expect(!a.shuffle);
    try std.testing.expectEqual(@as(u32, 5), a.timeout_s);
    try std.testing.expectEqual(@as(u8, 3), a.alone_runs);
    try std.testing.expectEqual(@as(?u32, 2), a.only_batch);
    try std.testing.expectEqualStrings("css", a.filter.?);
    const d = try Args.parse(&.{"x"});
    try std.testing.expectEqual(@as(u32, 10), d.batch);
    try std.testing.expect(d.shuffle);
    try std.testing.expectEqual(@as(?u64, null), d.seed);
    try std.testing.expectError(error.MissingExecutable, Args.parse(&.{}));
    try std.testing.expectError(error.UnknownOption, Args.parse(&.{ "x", "--bogus" }));
    try std.testing.expectError(error.UnexpectedArgument, Args.parse(&.{ "x", "y" }));
}

const Printer = struct {
    out: *Io.Writer,
    names: []const []const u8,
    seed: u64,
    step: u32,

    fn onVerdict(ctx: ?*anyopaque, t: u32, rec: *const sched.TestRecord) void {
        const p: *Printer = @ptrCast(@alignCast(ctx.?));
        if (rec.verdict.ok()) return;
        p.out.print("{s} {s} (first run: {t}, batch {d} position {d}, seed 0x{x}; alone:", .{
            rec.verdict.label(), p.names[t], rec.first, rec.batch, rec.position, p.seed,
        }) catch {};
        for (rec.aloneRuns()) |s| p.out.print(" {t}", .{s}) catch {};
        if (rec.replay) |s| p.out.print("; after its batch prefix: {t}", .{s}) catch {};
        p.out.writeAll(")\n") catch {};
        const tail = lastLines(rec.output, 40);
        if (tail.len != 0) p.out.print("{s}\n", .{tail}) catch {};
        p.out.flush() catch {};
    }

    fn onProgress(ctx: ?*anyopaque, done: u32, total: u32) void {
        const p: *Printer = @ptrCast(@alignCast(ctx.?));
        if (done % p.step != 0 and done != total) return;
        p.out.print("  {d}/{d} batches\n", .{ done, total }) catch {};
        p.out.flush() catch {};
    }
};

/// The last `n` lines of `s` (the end of a crash report is the useful part).
fn lastLines(s: []const u8, n: usize) []const u8 {
    const trimmed = std.mem.trimEnd(u8, s, "\n");
    var count: usize = 0;
    var i = trimmed.len;
    while (i > 0) : (i -= 1) {
        if (trimmed[i - 1] == '\n') {
            count += 1;
            if (count == n) return trimmed[i..];
        }
    }
    return trimmed;
}

test "lastLines keeps the end" {
    try std.testing.expectEqualStrings("c\nd", lastLines("a\nb\nc\nd\n", 2));
    try std.testing.expectEqualStrings("a\nb", lastLines("a\nb", 5));
    try std.testing.expectEqualStrings("", lastLines("", 5));
}

fn fmtSeconds(ns: u64) f64 {
    return @as(f64, @floatFromInt(ns)) / std.time.ns_per_s;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var stdout_buf: [8192]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    const argv = try init.minimal.args.toSlice(arena);
    const args = Args.parse(argv[1..]) catch |err| {
        try out.print("test_launcher: {t}\n{s}", .{ err, usage });
        try out.flush();
        std.process.exit(2);
    };

    const seed: u64 = args.seed orelse seed: {
        var bytes: [8]u8 = undefined;
        io.random(&bytes);
        break :seed std.mem.readInt(u64, &bytes, .little);
    };
    const jobs: u32 = args.jobs orelse @intCast(std.Thread.getCpuCount() catch 1);
    const exe = args.exe.?;
    const child_argv = [_][]const u8{
        exe,
        "--listen=-",
        try std.fmt.allocPrint(arena, "--seed=0x{x}", .{plan_mod.childSeed(seed)}),
    };

    const started = Io.Clock.Timestamp.now(io, .awake);
    const md = try child_mod.queryMetadata(gpa, io, &child_argv);
    defer md.deinit(gpa);

    var selected: std.ArrayList(u32) = .empty;
    for (md.names, md.expects_panic, 0..) |name, panics, i| {
        if (panics) continue;
        if (args.filter) |f| if (std.mem.indexOf(u8, name, f) == null) continue;
        try selected.append(arena, @intCast(i));
    }

    if (args.list) {
        for (selected.items) |i| try out.print("{s}\n", .{md.names[i]});
        return;
    }

    var plan = try plan_mod.make(gpa, selected.items, .{ .seed = seed, .shuffle = args.shuffle, .batch_size = args.batch });
    defer plan.deinit(gpa);

    try out.print(
        "test_launcher: {s}: {d} tests, seed 0x{x}, {s}, batch {d} -> {d} processes, {d} jobs, timeout {d} s\n" ++
            "  replay: test_launcher {s} --seed=0x{x} --batch={d}{s}\n",
        .{
            std.fs.path.basename(exe),                       selected.items.len, seed,
            if (args.shuffle) "shuffled" else "index order", args.batch,         plan.batches.len,
            jobs,                                            args.timeout_s,     exe,
            seed,                                            args.batch,         if (args.shuffle) "" else " --no-shuffle",
        },
    );
    try out.flush();

    var executor = try child_mod.Executor.init(gpa, io, &child_argv, @as(u64, args.timeout_s) * std.time.ns_per_s, jobs);
    defer executor.deinit();

    var printer: Printer = .{
        .out = out,
        .names = md.names,
        .seed = seed,
        .step = @max(@as(u32, @intCast(plan.batches.len / 10)), 1),
    };
    var run = try sched.Run.init(gpa, io, &plan, md.names.len, executor.executor(), .{
        .jobs = jobs,
        .alone_runs = args.alone_runs,
        .on_verdict = Printer.onVerdict,
        .on_verdict_ctx = &printer,
        .on_progress = Printer.onProgress,
        .only_batch = args.only_batch,
    });
    defer run.deinit();
    try run.execute();
    const wall_ns: u64 = @intCast(started.untilNow(io).raw.nanoseconds);

    const c = run.counts();
    const exit_failures = executor.exit_failures.load(.monotonic);
    try out.print(
        "test_launcher: {s}: PASS {d}  SKIP {d}  FAIL {d}  ORDER-DEPENDENT {d}  FLAKY {d}  NOT-RUN {d}\n" ++
            "  wall {d:.1} s, child CPU {d:.1} s, {d} processes, peak child RSS {d} MB, {d} exited non-zero after exit\n",
        .{
            std.fs.path.basename(exe), c.pass,                                       c.skip,                         c.fail,                                         c.order_dependent, c.flaky, c.not_run,
            fmtSeconds(wall_ns),       fmtSeconds(executor.cpu_ns.load(.monotonic)), run.processes.load(.monotonic), executor.peak_rss.load(.monotonic) / (1 << 20), exit_failures,
        },
    );

    if (args.out) |path| {
        var aw: Io.Writer.Allocating = .init(arena);
        for (0..run.batchCount()) |k| {
            for (plan.batchTests(run.batchId(@intCast(k)))) |t| {
                try report.writeLine(&aw.writer, md.names[t], t, &run.records[t], seed);
            }
        }
        if (std.fs.path.dirname(path)) |dir| try Io.Dir.cwd().createDirPath(io, dir);
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = aw.written() });
        // The output of every test that did not pass, beside it.
        var log: Io.Writer.Allocating = .init(arena);
        for (0..run.batchCount()) |k| {
            for (plan.batchTests(run.batchId(@intCast(k)))) |t| {
                const rec = &run.records[t];
                if (rec.verdict.ok()) continue;
                try log.writer.print("=== {s} {s} (batch {d} position {d}, seed 0x{x})\n{s}\n", .{
                    rec.verdict.label(), md.names[t], rec.batch, rec.position, seed, rec.output,
                });
            }
        }
        const log_path = try std.fmt.allocPrint(arena, "{s}.log", .{path});
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = log_path, .data = log.written() });
        try out.print("  results: {s} (failure output: {s})\n", .{ path, log_path });
    }
    try out.flush();

    if (c.bad() != 0 or exit_failures != 0) std.process.exit(1);
}
