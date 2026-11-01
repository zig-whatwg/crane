//! Crane's test launcher: runs ONE compiled Zig test executable as many
//! child processes, in seeded batches, and classifies every failure.
//!
//!   test_launcher <test-exe> [--jobs=N] [--batch=B] [--seed=S] [--no-shuffle]
//!                 [--timeout=SECONDS] [--alone-runs=R] [--only-batch=K]
//!                 [--filter=SUBSTRING] [--out=FILE.jsonl] [--list] ...
//!
//! `zig build test` runs every test executable through this, in server mode
//! (`--listen=-`, server.zig): the build runner talks the Zig test-runner
//! protocol to the launcher as it would to the executable. Run by hand, it
//! prints its own report.
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
//! Batch size 1 gives per-test process isolation from the one compiled
//! suite binary (the retired `-Dtest-isolation=file` compiled 1,592
//! executables for less); batch 0 runs the whole suite in one process.
//!
//! The seed: `zig build test` uses one derived from the test executable's
//! bytes (`--launch-seed=digest`, the server-mode default), so an unchanged
//! executable gets the same plan and the build runner's cache can skip it;
//! explicit shuffled runs pass `--launch-seed=random` (or a value). Either
//! way the seed is printed with a replay command.

const std = @import("std");
const Io = std.Io;
const plan_mod = @import("plan.zig");
const sched = @import("scheduler.zig");
const child_mod = @import("child.zig");
const report = @import("report.zig");
const server_mod = @import("server.zig");
const Slots = @import("slots.zig").Slots;

test {
    _ = plan_mod;
    _ = sched;
    _ = child_mod;
    _ = report;
    _ = server_mod;
    _ = @import("slots.zig");
    _ = Args;
    // Analyse main, so `zig build test` catches what only the executable uses.
    _ = &main;
}

/// Where the run's seed comes from.
const SeedSpec = union(enum) {
    /// A hash of the test executable's bytes: the same executable, the same
    /// plan (what `zig build test` uses, so its cache holds).
    digest,
    /// Fresh, printed.
    random,
    value: u64,

    fn parse(text: []const u8) !SeedSpec {
        if (std.mem.eql(u8, text, "digest")) return .digest;
        if (std.mem.eql(u8, text, "random")) return .random;
        return .{ .value = try plan_mod.parseSeed(text) };
    }
};

const Args = struct {
    exe: ?[]const u8 = null,
    jobs: ?u32 = null,
    batch: u32 = 10,
    /// `--seed=`; in server mode the build runner passes its own `--seed=`,
    /// which is ignored there (only `--launch-seed=` counts).
    seed: ?SeedSpec = null,
    launch_seed: ?SeedSpec = null,
    shuffle: bool = true,
    timeout_s: u32 = 60,
    slow_factor: u32 = 4,
    alone_runs: u8 = 2,
    only_batch: ?u32 = null,
    filter: ?[]const u8 = null,
    out: ?[]const u8 = null,
    timings: ?[]const u8 = null,
    slots_dir: ?[]const u8 = null,
    cache_dir: ?[]const u8 = null,
    name: ?[]const u8 = null,
    slow: []const []const u8 = &.{},
    list: bool = false,
    listen: bool = false,

    fn parse(arena: std.mem.Allocator, args: []const []const u8) !Args {
        var a: Args = .{};
        var slow: std.ArrayList([]const u8) = .empty;
        for (args) |arg| {
            if (value(arg, "--jobs=") orelse value(arg, "--parallel=")) |v| {
                // --parallel= too: the pool's crane-measure.sh rewrites it to
                // the runner share a run gets.
                a.jobs = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--batch=")) |v| {
                a.batch = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--seed=")) |v| {
                a.seed = try SeedSpec.parse(v);
            } else if (value(arg, "--launch-seed=")) |v| {
                a.launch_seed = try SeedSpec.parse(v);
            } else if (std.mem.eql(u8, arg, "--no-shuffle")) {
                a.shuffle = false;
            } else if (value(arg, "--timeout=")) |v| {
                a.timeout_s = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--slow-factor=")) |v| {
                a.slow_factor = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--slow=")) |v| {
                try slow.append(arena, v);
            } else if (value(arg, "--alone-runs=")) |v| {
                a.alone_runs = @min(try std.fmt.parseUnsigned(u8, v, 10), sched.max_alone_runs);
            } else if (value(arg, "--only-batch=")) |v| {
                a.only_batch = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--filter=")) |v| {
                a.filter = v;
            } else if (value(arg, "--out=")) |v| {
                a.out = v;
            } else if (value(arg, "--timings=")) |v| {
                a.timings = v;
            } else if (value(arg, "--slots-dir=")) |v| {
                a.slots_dir = v;
            } else if (value(arg, "--cache-dir=")) |v| {
                a.cache_dir = v;
            } else if (value(arg, "--name=")) |v| {
                a.name = v;
            } else if (std.mem.eql(u8, arg, "--list")) {
                a.list = true;
            } else if (std.mem.eql(u8, arg, "--listen=-")) {
                a.listen = true;
            } else if (std.mem.startsWith(u8, arg, "--")) {
                return error.UnknownOption;
            } else if (a.exe == null) {
                a.exe = arg;
            } else return error.UnexpectedArgument;
        }
        if (a.exe == null) return error.MissingExecutable;
        a.slow = slow.items;
        return a;
    }

    fn value(arg: []const u8, comptime prefix: []const u8) ?[]const u8 {
        return if (std.mem.startsWith(u8, arg, prefix)) arg[prefix.len..] else null;
    }

    /// The seed spec in force: `--launch-seed=` first; then, outside server
    /// mode, `--seed=`; then the mode's default (server: digest; by hand:
    /// random).
    fn seedSpec(a: Args) SeedSpec {
        if (a.launch_seed) |s| return s;
        if (!a.listen) if (a.seed) |s| return s;
        return if (a.listen) .digest else .random;
    }
};

const usage =
    \\usage: test_launcher <test-exe> [options]
    \\  --batch=B         tests per child process (default 10; 1 = per-test isolation; 0 = the whole suite)
    \\  --jobs=N          child processes at once (default: the CPU count; --parallel=N is the same)
    \\  --seed=S          the run's seed: decimal, 0x hex, `random` or `digest` (default: random, printed)
    \\  --launch-seed=S   the same, and the one that counts in server mode (default there: digest)
    \\  --no-shuffle      index order, as the build runner runs (batches still apply)
    \\  --timeout=S       per-test timeout in seconds (default 60)
    \\  --slow=NAME       a test (full name) declared slow: its timeout is --slow-factor times longer
    \\  --slow-factor=F   default 4 (Chromium's and V8's SLOW)
    \\  --alone-runs=R    re-runs of each failed test alone (default 2)
    \\  --only-batch=K    run only batch K of the plan the seed and batch size make
    \\  --filter=TEXT     only tests whose name contains TEXT (selected at run time)
    \\  --out=FILE        the result file, one JSON line per test (+ FILE.log: failures' output)
    \\  --timings=FILE    an earlier result file: claim the longest batches first
    \\  --slots-dir=DIR   share a cap of --jobs test processes with every launcher using DIR
    \\  --name=NAME       the suite's name in the report (default: the executable's)
    \\  --listen=-        server mode: answer the Zig test-runner protocol (what `zig build test` does)
    \\
;

test "args: options, defaults, and errors" {
    const arena = testing.allocator;
    const a = try Args.parse(arena, &.{ "zig-out/x", "--jobs=4", "--batch=1", "--seed=0x10", "--no-shuffle", "--timeout=5", "--alone-runs=3", "--only-batch=2", "--filter=css", "--out=o.jsonl" });
    try std.testing.expectEqualStrings("zig-out/x", a.exe.?);
    try std.testing.expectEqual(@as(?u32, 4), a.jobs);
    try std.testing.expectEqual(@as(u32, 1), a.batch);
    try std.testing.expectEqual(SeedSpec{ .value = 16 }, a.seedSpec());
    try std.testing.expect(!a.shuffle);
    try std.testing.expectEqual(@as(u32, 5), a.timeout_s);
    try std.testing.expectEqual(@as(u8, 3), a.alone_runs);
    try std.testing.expectEqual(@as(?u32, 2), a.only_batch);
    try std.testing.expectEqualStrings("css", a.filter.?);
    const d = try Args.parse(arena, &.{"x"});
    try std.testing.expectEqual(@as(u32, 10), d.batch);
    try std.testing.expect(d.shuffle);
    try std.testing.expectEqual(SeedSpec.random, d.seedSpec());
    try std.testing.expectEqual(@as(?u32, 3), (try Args.parse(arena, &.{ "x", "--parallel=3" })).jobs);
    try std.testing.expectError(error.MissingExecutable, Args.parse(arena, &.{}));
    try std.testing.expectError(error.UnknownOption, Args.parse(arena, &.{ "x", "--bogus" }));
    try std.testing.expectError(error.UnexpectedArgument, Args.parse(arena, &.{ "x", "y" }));
}

test "args: server mode takes the digest seed and ignores the build runner's --seed" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // What `zig build test` passes: our options, then the build runner's.
    const a = try Args.parse(arena, &.{ "tests-css", "--batch=10", "--slow=a.test.slow one", "--slow=b", "--cache-dir=.zig-cache", "--seed=0x1234", "--listen=-" });
    try std.testing.expect(a.listen);
    try std.testing.expectEqual(SeedSpec.digest, a.seedSpec());
    try std.testing.expectEqualStrings(".zig-cache", a.cache_dir.?);
    try std.testing.expectEqual(@as(usize, 2), a.slow.len);
    try std.testing.expectEqualStrings("a.test.slow one", a.slow[0]);
    // -Dlaunch-seed=random / a value.
    const r = try Args.parse(arena, &.{ "x", "--launch-seed=random", "--seed=0x1234", "--listen=-" });
    try std.testing.expectEqual(SeedSpec.random, r.seedSpec());
    const v = try Args.parse(arena, &.{ "x", "--launch-seed=0x7a11", "--listen=-" });
    try std.testing.expectEqual(SeedSpec{ .value = 0x7a11 }, v.seedSpec());
    try std.testing.expectEqual(SeedSpec.digest, try SeedSpec.parse("digest"));
}

/// The digest seed: a hash of the executable's bytes. The same build of a
/// suite gets the same plan; a rebuilt one, a new plan. (The hash need not
/// be stable across Zig versions: a replay names the seed itself.)
fn seedFromFile(io: Io, path: []const u8) !u64 {
    const file = try Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var buf: [1 << 16]u8 = undefined;
    var r = file.reader(io, &buf);
    var h = std.hash.Wyhash.init(0x6372616e65); // "crane"
    while (true) {
        const chunk = r.interface.peekGreedy(1) catch |err| switch (err) {
            error.EndOfStream => break,
            error.ReadFailed => return r.err.?,
        };
        h.update(chunk);
        r.interface.toss(chunk.len);
    }
    return h.final();
}

test "the digest seed is a function of the executable's bytes" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "a", .data = "the same bytes" });
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "b", .data = "the same bytes" });
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "c", .data = "other bytes" });
    const base = try std.fmt.allocPrint(testing.allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    defer testing.allocator.free(base);
    var paths: [3][]u8 = undefined;
    for (&paths, [_][]const u8{ "a", "b", "c" }) |*p, n| p.* = try std.fs.path.join(testing.allocator, &.{ base, n });
    defer for (paths) |p| testing.allocator.free(p);
    const a = try seedFromFile(testing.io, paths[0]);
    try testing.expectEqual(a, try seedFromFile(testing.io, paths[1]));
    try testing.expect(a != try seedFromFile(testing.io, paths[2]));
}

const Printer = struct {
    out: *Io.Writer,
    names: []const []const u8,
    seed: u64,
    step: u32,

    fn onVerdict(ctx: ?*anyopaque, t: u32, rec: *const sched.TestRecord) void {
        const p: *Printer = @ptrCast(@alignCast(ctx.?));
        if (rec.verdict.ok()) return;
        report.writeVerdictBlock(p.out, p.names[t], rec, p.seed) catch {};
        p.out.flush() catch {};
    }

    fn onProgress(ctx: ?*anyopaque, done: u32, total: u32) void {
        const p: *Printer = @ptrCast(@alignCast(ctx.?));
        if (done % p.step != 0 and done != total) return;
        p.out.print("  {d}/{d} batches\n", .{ done, total }) catch {};
        p.out.flush() catch {};
    }
};

fn fmtSeconds(ns: u64) f64 {
    return @as(f64, @floatFromInt(ns)) / std.time.ns_per_s;
}

const testing = std.testing;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Streaming, not positional: stdout and stderr are often files other
    // writers append to (a log shared with `time` and the pool scripts), and
    // a positional writer would overwrite them from offset 0.
    var stdout_buf: [8192]u8 = undefined;
    var stdout_writer = Io.File.stdout().writerStreaming(io, &stdout_buf);
    var stderr_buf: [8192]u8 = undefined;
    var stderr_writer = Io.File.stderr().writerStreaming(io, &stderr_buf);

    const argv = try init.minimal.args.toSlice(arena);
    const args = Args.parse(arena, argv[1..]) catch |err| {
        const w = &stderr_writer.interface;
        try w.print("test_launcher: {t}\n{s}", .{ err, usage });
        try w.flush();
        std.process.exit(2);
    };
    // In server mode stdout is the protocol; the report goes to stderr,
    // which the build runner shows.
    const out = if (args.listen) &stderr_writer.interface else &stdout_writer.interface;
    defer out.flush() catch {};

    const exe = args.exe.?;
    const name = args.name orelse std.fs.path.basename(exe);
    const seed: u64 = switch (args.seedSpec()) {
        .value => |v| v,
        .digest => try seedFromFile(io, exe),
        .random => seed: {
            var bytes: [8]u8 = undefined;
            io.random(&bytes);
            break :seed std.mem.readInt(u64, &bytes, .little);
        },
    };
    const jobs: u32 = args.jobs orelse @intCast(std.Thread.getCpuCount() catch 1);
    const child_argv = [_][]const u8{
        exe,
        "--listen=-",
        try std.fmt.allocPrint(arena, "--seed=0x{x}", .{plan_mod.childSeed(seed)}),
    };

    const started = Io.Clock.Timestamp.now(io, .awake);
    const md = try child_mod.queryMetadata(gpa, io, &child_argv);
    defer md.deinit(gpa);

    var index_of: std.StringHashMapUnmanaged(u32) = .empty;
    for (md.names, 0..) |n, i| try index_of.put(arena, n, @intCast(i));

    var selected: std.ArrayList(u32) = .empty;
    const is_selected = try arena.alloc(bool, md.names.len);
    @memset(is_selected, false);
    for (md.names, md.expects_panic, 0..) |n, panics, i| {
        if (panics) continue;
        if (args.filter) |f| if (std.mem.indexOf(u8, n, f) == null) continue;
        try selected.append(arena, @intCast(i));
        is_selected[i] = true;
    }

    if (args.list) {
        for (selected.items) |i| try out.print("{s}\n", .{md.names[i]});
        return;
    }

    // Declared slow tests. A name the executable lacks is reported: the
    // list must not outlive its tests unnoticed.
    const slow = try arena.alloc(bool, md.names.len);
    @memset(slow, false);
    for (args.slow) |n| {
        if (index_of.get(n)) |i| slow[i] = true else try out.print("test_launcher: {s}: --slow names no test of this executable: {s}\n", .{ name, n });
    }

    var plan = try plan_mod.make(gpa, selected.items, .{ .seed = seed, .shuffle = args.shuffle, .batch_size = args.batch });
    defer plan.deinit(gpa);

    // Longest batches first, from an earlier run's durations.
    var claim_order: ?[]u32 = null;
    defer if (claim_order) |o| gpa.free(o);
    if (args.timings) |path| timings: {
        const text = Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20)) catch break :timings;
        const expected = try arena.alloc(?u64, md.names.len);
        @memset(expected, null);
        report.readTimings(arena, text, &index_of, expected);
        claim_order = try sched.longestFirst(gpa, &plan, expected);
    }

    var executor = try child_mod.Executor.init(gpa, io, &child_argv, @as(u64, args.timeout_s) * std.time.ns_per_s, jobs);
    defer executor.deinit();
    executor.slow = slow;
    executor.slow_factor = args.slow_factor;
    // The build-wide process cap: the given directory, or in server mode one
    // in the build's cache, which every launcher of the build shares.
    const slots_dir: ?[]const u8 = args.slots_dir orelse if (args.listen and args.cache_dir != null)
        try std.fs.path.join(arena, &.{ args.cache_dir.?, "test-launcher-slots" })
    else
        null;
    var slots: ?Slots = if (slots_dir) |d| try Slots.open(io, d, jobs) else null;
    defer if (slots) |*s| s.close();
    if (slots) |*s| executor.slots = s;

    const replay = try std.fmt.allocPrint(arena, "test_launcher {s} --seed=0x{x} --batch={d}{s}", .{
        exe, seed, args.batch, if (args.shuffle) "" else " --no-shuffle",
    });

    var printer: Printer = .{
        .out = out,
        .names = md.names,
        .seed = seed,
        .step = @max(@as(u32, @intCast(plan.batches.len / 10)), 1),
    };
    var session: server_mod.Session = undefined;
    var run = try sched.Run.init(gpa, io, &plan, md.names.len, executor.executor(), .{
        .jobs = jobs,
        .alone_runs = args.alone_runs,
        .on_verdict = if (args.listen) server_mod.Session.onVerdict else Printer.onVerdict,
        .on_verdict_ctx = if (args.listen) @ptrCast(&session) else @ptrCast(&printer),
        .on_progress = if (args.listen) null else Printer.onProgress,
        .only_batch = args.only_batch,
        .claim_order = claim_order,
    });
    defer run.deinit();

    if (args.listen) {
        session = try server_mod.Session.init(gpa, io, md.names, md.expects_panic, is_selected, &run, seed);
        defer session.deinit(gpa);
        var stdin_buf: [4096]u8 = undefined;
        var stdin_reader = Io.File.stdin().readerStreaming(io, &stdin_buf);
        try server_mod.serve(&session, gpa, &stdin_reader.interface, &stdout_writer.interface, out);
        session.finish();
        if (session.run_error) |err| return err;
    } else {
        try out.print(
            "test_launcher: {s}: {d} tests, seed 0x{x}, {s}, batch {d} -> {d} processes, {d} jobs, timeout {d} s\n  replay: {s}\n",
            .{
                name,       selected.items.len, seed, if (args.shuffle) "shuffled" else "index order",
                args.batch, plan.batches.len,   jobs, args.timeout_s,
                replay,
            },
        );
        try out.flush();
        try run.execute();
    }
    const wall_ns: u64 = @intCast(started.untilNow(io).raw.nanoseconds);

    const c = run.counts();
    const exit_failures = executor.exit_failures.load(.monotonic);
    const cpu_s = fmtSeconds(executor.cpu_ns.load(.monotonic));
    const rss_mb = executor.peak_rss.load(.monotonic) / (1 << 20);
    if (args.listen) {
        // One line per suite: in `zig build test` this is the step's stderr,
        // which prints each suite's seed and its own wall time. The replay
        // command only when something did not pass.
        try out.print(
            "test_launcher: {s}: seed 0x{x}, batch {d}: PASS {d} SKIP {d} FAIL {d} ORDER-DEPENDENT {d} FLAKY {d} NOT-RUN {d}; wall {d:.1} s, child CPU {d:.1} s, {d} processes, peak child RSS {d} MB\n",
            .{ name, seed, args.batch, c.pass, c.skip, c.fail, c.order_dependent, c.flaky, c.not_run, fmtSeconds(wall_ns), cpu_s, run.processes.load(.monotonic), rss_mb },
        );
        if (c.bad() != 0) try out.print("  replay: {s}\n", .{replay});
        if (exit_failures != 0) try out.print("  {d} test processes exited non-zero after exit\n", .{exit_failures});
    } else try out.print(
        "test_launcher: {s}: PASS {d}  SKIP {d}  FAIL {d}  ORDER-DEPENDENT {d}  FLAKY {d}  NOT-RUN {d}  (seed 0x{x}, batch {d}, {d} jobs)\n" ++
            "  wall {d:.1} s, child CPU {d:.1} s, {d} processes, peak child RSS {d} MB, {d} exited non-zero after exit\n",
        .{
            name,                c.pass, c.skip,                         c.fail, c.order_dependent, c.flaky, c.not_run, seed, args.batch, jobs,
            fmtSeconds(wall_ns), cpu_s,  run.processes.load(.monotonic), rss_mb, exit_failures,
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
        if (!args.listen) try out.print("  results: {s} (failure output: {s})\n", .{ path, log_path });
    }
    try out.flush();

    // In server mode the verdicts reached the build runner test by test; a
    // child that exited non-zero after `exit` has no test to blame, so it
    // fails the step here. By hand, any non-pass fails the run.
    if (exit_failures != 0) std.process.exit(1);
    if (!args.listen and c.bad() != 0) std.process.exit(1);
}
