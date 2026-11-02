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
const verify_mod = @import("verify.zig");

test {
    _ = plan_mod;
    _ = sched;
    _ = child_mod;
    _ = report;
    _ = server_mod;
    _ = @import("slots.zig");
    _ = verify_mod;
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

/// ThreadSanitizer's slowdown, for the per-test timeout: tests-dom's 642
/// tests took 153 s of test time plain and 1,413 s under TSAN on chat.local
/// (9.2x; the heaviest 30.6 s -> past 300 s, lane tsan1, 2026-11-02). Gecko
/// gives TSAN 120 s where a plain run gets 45 s (tmp/analysis/test-research/
/// gecko.md). The timeout is there to catch hangs: 4x (1,200 s by default)
/// leaves the heaviest test of tests-dom four times its TSAN time.
const tsan_timeout_factor = 4;

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
    /// The executable is built with ThreadSanitizer (-Dsanitize-thread).
    sanitize_thread: bool = false,
    tsan_suppressions: ?[]const u8 = null,
    /// The many-Browsers variant (-Dmany-browsers).
    many_browsers: bool = false,
    /// Tests that need their process to themselves (`--alone=NAME`, each with
    /// the `--alone-reason=` after it): under --many-browsers each runs in a
    /// process of its own, with no busy Browser beside it, and the run names
    /// each with its reason - declared, never a silent skip (build.zig
    /// suite_configs `alone`).
    alone: []const Declared = &.{},
    /// Tests excluded from the ThreadSanitizer variant (`--tsan-skip=NAME`,
    /// each with the `--tsan-skip-reason=` after it): under
    /// --sanitize-thread each is not run - reported as skipped - and the run
    /// names it with its reason. Only a test whose subject is real time
    /// itself, which the instrumentation's slowdown changes (V8's status
    /// files SKIP such tests under tsan); a test that merely waits on a time
    /// budget is fixed to wait on its condition instead (build.zig
    /// suite_configs `tsan_skip`).
    tsan_skip: []const Declared = &.{},
    /// Report every non-pass without failing (server.Session.report_only).
    report_only: bool = false,
    /// Verify mode (verify.zig): the tests whose names start with any of
    /// these, `verify_batched` times in one process and `verify_alone` times
    /// each alone.
    verify: []const []const u8 = &.{},
    verify_batched: u32 = 10,
    verify_alone: u32 = 5,

    fn parse(arena: std.mem.Allocator, args: []const []const u8) !Args {
        var a: Args = .{};
        var slow: std.ArrayList([]const u8) = .empty;
        var verify: std.ArrayList([]const u8) = .empty;
        var alone: std.ArrayList(Declared) = .empty;
        var tsan_skip: std.ArrayList(Declared) = .empty;
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
            } else if (std.mem.eql(u8, arg, "--sanitize-thread")) {
                a.sanitize_thread = true;
            } else if (value(arg, "--tsan-suppressions=")) |v| {
                a.tsan_suppressions = v;
            } else if (std.mem.eql(u8, arg, "--many-browsers")) {
                a.many_browsers = true;
            } else if (value(arg, "--alone=")) |v| {
                try alone.append(arena, .{ .name = v });
            } else if (value(arg, "--alone-reason=")) |v| {
                if (alone.items.len == 0) return error.AloneReasonWithoutAlone;
                alone.items[alone.items.len - 1].reason = v;
            } else if (value(arg, "--tsan-skip=")) |v| {
                try tsan_skip.append(arena, .{ .name = v });
            } else if (value(arg, "--tsan-skip-reason=")) |v| {
                if (tsan_skip.items.len == 0) return error.TsanSkipReasonWithoutTsanSkip;
                tsan_skip.items[tsan_skip.items.len - 1].reason = v;
            } else if (std.mem.eql(u8, arg, "--report-only")) {
                a.report_only = true;
            } else if (value(arg, "--verify=")) |v| {
                try verify.append(arena, v);
            } else if (value(arg, "--verify-batched=")) |v| {
                a.verify_batched = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (value(arg, "--verify-alone=")) |v| {
                a.verify_alone = try std.fmt.parseUnsigned(u32, v, 10);
            } else if (std.mem.eql(u8, arg, "--listen=-")) {
                a.listen = true;
            } else if (std.mem.startsWith(u8, arg, "--")) {
                return error.UnknownOption;
            } else if (a.exe == null) {
                a.exe = arg;
            } else return error.UnexpectedArgument;
        }
        if (a.exe == null) return error.MissingExecutable;
        if (a.tsan_suppressions != null and !a.sanitize_thread) return error.SuppressionsWithoutSanitizeThread;
        a.slow = slow.items;
        a.verify = verify.items;
        a.alone = alone.items;
        for (a.alone) |declared| if (declared.reason.len == 0) return error.AloneWithoutReason;
        a.tsan_skip = tsan_skip.items;
        for (a.tsan_skip) |declared| if (declared.reason.len == 0) return error.TsanSkipWithoutReason;
        // Verify mode is a run of its own, with its own report: never the
        // build runner's protocol.
        if (a.verify.len != 0 and a.listen) return error.VerifyInServerMode;
        return a;
    }

    fn value(arg: []const u8, comptime prefix: []const u8) ?[]const u8 {
        return if (std.mem.startsWith(u8, arg, prefix)) arg[prefix.len..] else null;
    }

    /// The per-test timeout in force: `--timeout`, times
    /// `tsan_timeout_factor` for an executable built with ThreadSanitizer.
    fn effectiveTimeout(a: Args) u32 {
        return if (a.sanitize_thread) a.timeout_s *| tsan_timeout_factor else a.timeout_s;
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

/// A test declared by name with its reason: one that needs its process to
/// itself (`--alone`), or one excluded from the ThreadSanitizer variant
/// (`--tsan-skip`).
pub const Declared = struct {
    /// The test's full name.
    name: []const u8,
    /// Why: what about it a second Browser, or the instrumentation's
    /// slowdown, would change. Required.
    reason: []const u8 = "",
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
    \\  --sanitize-thread the executable is built with ThreadSanitizer: TSAN_OPTIONS=halt_on_error=1 in
    \\                    every child, so a race crashes its process and is blamed on the running test
    \\  --tsan-suppressions=FILE  with --sanitize-thread: the suppression file (proven false positives only)
    \\  --many-browsers   the many-Browsers variant: every test runs beside a busy Browser on another
    \\                    thread (CRANE_TEST_MANY_BROWSERS=1; the Crane test runner starts it)
    \\  --alone=NAME      with --many-browsers: a test (full name) that needs its process to itself runs in
    \\                    one of its own with no busy Browser, and the run names it; each needs the
    \\  --alone-reason=R  that follows it: why (printed with it)
    \\  --tsan-skip=NAME  with --sanitize-thread: a test (full name) whose subject is real time is not run, and
    \\                    the run names it; each needs the
    \\  --tsan-skip-reason=R  that follows it: why (printed with it)
    \\  --verify=PREFIX   verify mode: the tests whose names start with PREFIX (repeatable; build.zig's
    \\                    test-verify passes one per changed file, "<file>.test."), each run
    \\                    --verify-batched times in one process and --verify-alone times alone;
    \\                    any run that is not a pass fails (defaults 10 and 5)
    \\  --report-only     print and record every verdict, but answer the build runner `pass` for a
    \\                    failure and exit 0 for one: a variant's report mode (a TEMPORARY suite row)
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
    const t = try Args.parse(arena, &.{ "x", "--sanitize-thread", "--tsan-suppressions=/s.txt", "--many-browsers", "--report-only" });
    try std.testing.expect(t.sanitize_thread and t.many_browsers and t.report_only);
    try std.testing.expectEqualStrings("/s.txt", t.tsan_suppressions.?);
    try std.testing.expect(!d.sanitize_thread and !d.many_browsers);
    try std.testing.expectError(error.SuppressionsWithoutSanitizeThread, Args.parse(arena, &.{ "x", "--tsan-suppressions=/s.txt" }));
    // ThreadSanitizer's slowdown stretches the timeout; nothing else does.
    try std.testing.expectEqual(@as(u32, 300 * tsan_timeout_factor), (try Args.parse(arena, &.{ "x", "--sanitize-thread", "--timeout=300" })).effectiveTimeout());
    try std.testing.expectEqual(@as(u32, 300), (try Args.parse(arena, &.{ "x", "--many-browsers", "--timeout=300" })).effectiveTimeout());
    try std.testing.expectEqual(@as(u32, 10), d.verify_batched);
    try std.testing.expectEqual(@as(u32, 5), d.verify_alone);
    try std.testing.expectError(error.MissingExecutable, Args.parse(arena, &.{}));
    try std.testing.expectError(error.UnknownOption, Args.parse(arena, &.{ "x", "--bogus" }));
    try std.testing.expectError(error.UnexpectedArgument, Args.parse(arena, &.{ "x", "y" }));
}

test "args: verify mode - prefixes, run counts, and never in server mode" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const v = try Args.parse(arena, &.{ "x", "--verify=a_test.test.", "--verify=sub.b_test.test.", "--verify-batched=1", "--verify-alone=0" });
    try std.testing.expectEqual(@as(usize, 2), v.verify.len);
    try std.testing.expectEqualStrings("sub.b_test.test.", v.verify[1]);
    try std.testing.expectEqual(@as(u32, 1), v.verify_batched);
    try std.testing.expectEqual(@as(u32, 0), v.verify_alone);
    try std.testing.expectError(error.VerifyInServerMode, Args.parse(arena, &.{ "x", "--verify=a.", "--listen=-" }));
}

test "args: a test declared alone carries its reason, and one without a reason is refused" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const a = try Args.parse(arena, &.{ "x", "--many-browsers", "--alone=f.test.counts the process", "--alone-reason=reads a process-wide count", "--alone=g.test.first isolate", "--alone-reason=must make the first isolate" });
    try std.testing.expectEqual(@as(usize, 2), a.alone.len);
    try std.testing.expectEqualStrings("f.test.counts the process", a.alone[0].name);
    try std.testing.expectEqualStrings("reads a process-wide count", a.alone[0].reason);
    try std.testing.expectEqualStrings("must make the first isolate", a.alone[1].reason);
    try std.testing.expectError(error.AloneWithoutReason, Args.parse(arena, &.{ "x", "--alone=f.test.t" }));
    try std.testing.expectError(error.AloneReasonWithoutAlone, Args.parse(arena, &.{ "x", "--alone-reason=why" }));
    const t = try Args.parse(arena, &.{ "x", "--sanitize-thread", "--tsan-skip=f.test.measured", "--tsan-skip-reason=its subject is real time" });
    try std.testing.expectEqual(@as(usize, 1), t.tsan_skip.len);
    try std.testing.expectEqualStrings("its subject is real time", t.tsan_skip[0].reason);
    try std.testing.expectError(error.TsanSkipWithoutReason, Args.parse(arena, &.{ "x", "--tsan-skip=f.test.t" }));
    try std.testing.expectError(error.TsanSkipReasonWithoutTsanSkip, Args.parse(arena, &.{ "x", "--tsan-skip-reason=why" }));
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
        .digest => seedFromFile(io, exe) catch |err|
            launcherFailure(out, "could not read {s} for its seed: {f}", .{ name, exe, child_mod.FmtError{ .err = err } }),
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
    const md = child_mod.queryMetadata(gpa, io, &child_argv) catch |err|
        launcherFailure(out, "could not list the tests of {s}: {f}", .{ name, exe, child_mod.FmtError{ .err = err } });
    defer md.deinit(gpa);

    var index_of: std.StringHashMapUnmanaged(u32) = .empty;
    for (md.names, 0..) |n, i| try index_of.put(arena, n, @intCast(i));

    var selected: std.ArrayList(u32) = .empty;
    const is_selected = try arena.alloc(bool, md.names.len);
    @memset(is_selected, false);
    // Excluded from the ThreadSanitizer variant: not run (a skip to the build
    // runner), each named with its reason - declared, never silent - and a
    // name the executable lacks reported, as for --slow.
    const tsan_skipped = try arena.alloc(bool, md.names.len);
    @memset(tsan_skipped, false);
    if (args.sanitize_thread) {
        for (args.tsan_skip) |declared| {
            const i = index_of.get(declared.name) orelse {
                try out.print("test_launcher: {s}: --tsan-skip names no test of this executable: {s}\n", .{ name, declared.name });
                continue;
            };
            tsan_skipped[i] = true;
        }
    }
    for (md.names, md.expects_panic, 0..) |n, panics, i| {
        if (panics) continue;
        if (args.filter) |f| if (std.mem.indexOf(u8, n, f) == null) continue;
        if (tsan_skipped[i]) {
            for (args.tsan_skip) |declared| if (std.mem.eql(u8, declared.name, n)) {
                try out.print("test_launcher: {s} [ThreadSanitizer]: SKIPPED, not run under ThreadSanitizer: {s}: {s}\n", .{ name, n, declared.reason });
                break;
            };
            continue;
        }
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

    // Declared alone: only the many-Browsers variant has a second Browser to
    // keep away. Each selected one is named with its reason - a test run
    // without the variant is declared, never silent - and a name the
    // executable lacks is reported, as for --slow.
    const alone = try arena.alloc(bool, md.names.len);
    @memset(alone, false);
    if (args.many_browsers) {
        for (args.alone) |declared| {
            const i = index_of.get(declared.name) orelse {
                try out.print("test_launcher: {s}: --alone names no test of this executable: {s}\n", .{ name, declared.name });
                continue;
            };
            alone[i] = true;
            if (is_selected[i]) try out.print("test_launcher: {s} [many Browsers]: runs ALONE, without the busy Browser: {s}: {s}\n", .{ name, declared.name, declared.reason });
        }
    }

    var plan = try plan_mod.make(gpa, selected.items, .{ .seed = seed, .shuffle = args.shuffle, .batch_size = args.batch, .alone = if (args.many_browsers) alone else &.{} });
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

    var executor = try child_mod.Executor.init(gpa, io, &child_argv, @as(u64, args.effectiveTimeout()) * std.time.ns_per_s, jobs);
    defer executor.deinit();
    // Every test child: the launcher's environment with the time zone and
    // locale fixed and the proxies cleared (child.testEnvironment).
    var test_environ = try child_mod.testEnvironment(gpa, init.environ_map, .{
        .sanitize_thread = if (args.sanitize_thread) .{ .suppressions = args.tsan_suppressions } else null,
        .many_browsers = args.many_browsers,
    });
    defer test_environ.deinit();
    executor.environ_map = &test_environ;
    // A process that runs a test declared alone: the same, without the busy
    // Browser.
    var alone_environ = try child_mod.testEnvironment(gpa, init.environ_map, .{
        .sanitize_thread = if (args.sanitize_thread) .{ .suppressions = args.tsan_suppressions } else null,
        .many_browsers = false,
    });
    defer alone_environ.deinit();
    executor.alone_environ_map = &alone_environ;
    executor.alone = alone;
    executor.slow = slow;
    executor.slow_factor = args.slow_factor;
    // The build-wide process cap: the given directory, or in server mode one
    // in the build's cache, which every launcher of the build shares.
    const slots_dir: ?[]const u8 = args.slots_dir orelse if (args.listen and args.cache_dir != null)
        try std.fs.path.join(arena, &.{ args.cache_dir.?, "test-launcher-slots" })
    else
        null;
    var slots: ?Slots = if (slots_dir) |d| (Slots.open(io, d, jobs) catch |err|
        launcherFailure(out, "could not open the test-process slot directory {s}: {f}", .{ name, d, child_mod.FmtError{ .err = err } })) else null;
    defer if (slots) |*s| s.close();
    if (slots) |*s| executor.slots = s;

    if (args.verify.len != 0) {
        const status = try runVerify(gpa, io, arena, out, name, md, args, &executor, jobs);
        try out.flush();
        if (status != 0) std.process.exit(status);
        return;
    }

    // A replay runs the same variants: the race or the busy Browser is part
    // of what failed.
    const replay = try std.fmt.allocPrint(arena, "test_launcher {s} --seed=0x{x} --batch={d}{s}{s}{s}", .{
        exe,                                                    seed,                                               args.batch, if (args.shuffle) "" else " --no-shuffle",
        if (args.sanitize_thread) " --sanitize-thread" else "", if (args.many_browsers) " --many-browsers" else "",
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
        session.report_only = args.report_only;
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
                args.batch, plan.batches.len,   jobs, args.effectiveTimeout(),
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
    // The variants the suite ran under, after its name: a nightly greps the
    // line, and a report-only suite's failures must not read as a gate's.
    const variants = try std.fmt.allocPrint(arena, "{s}{s}{s}", .{
        if (args.sanitize_thread) " [ThreadSanitizer]" else "",
        if (args.many_browsers) " [many Browsers]" else "",
        if (args.report_only) " [REPORT-ONLY]" else "",
    });
    if (args.listen) {
        // One line per suite: in `zig build test` this is the step's stderr,
        // which prints each suite's seed and its own wall time. The replay
        // command only when something did not pass.
        try out.print(
            "test_launcher: {s}{s}: seed 0x{x}, batch {d}: PASS {d} SKIP {d} FAIL {d} ORDER-DEPENDENT {d} FLAKY {d} NOT-RUN {d} LAUNCHER-ERROR {d}; wall {d:.1} s, child CPU {d:.1} s, {d} processes, peak child RSS {d} MB\n",
            .{ name, variants, seed, args.batch, c.pass, c.skip, c.fail, c.order_dependent, c.flaky, c.not_run, c.launcher_error, fmtSeconds(wall_ns), cpu_s, run.processes.load(.monotonic), rss_mb },
        );
        if (c.bad() != 0) try out.print("  replay: {s}\n", .{replay});
        if (exit_failures != 0) try out.print("  {d} test processes exited non-zero after exit\n", .{exit_failures});
    } else try out.print(
        "test_launcher: {s}{s}: PASS {d}  SKIP {d}  FAIL {d}  ORDER-DEPENDENT {d}  FLAKY {d}  NOT-RUN {d}  LAUNCHER-ERROR {d}  (seed 0x{x}, batch {d}, {d} jobs)\n" ++
            "  wall {d:.1} s, child CPU {d:.1} s, {d} processes, peak child RSS {d} MB, {d} exited non-zero after exit\n",
        .{
            name,                variants, c.pass,                         c.skip, c.fail,        c.order_dependent, c.flaky, c.not_run, c.launcher_error, seed, args.batch, jobs,
            fmtSeconds(wall_ns), cpu_s,    run.processes.load(.monotonic), rss_mb, exit_failures,
        },
    );

    // What the launcher could not run fails the run; say what, once.
    try report.writeLauncherErrors(out, gpa, name, md.names, run.records);

    if (args.out) |path| {
        writeResults(io, arena, path, md.names, &plan, &run, seed) catch |err|
            launcherFailure(out, "could not write the result file {s}: {f}", .{ name, path, child_mod.FmtError{ .err = err } });
        if (!args.listen) try out.print("  results: {s} (failure output: {s}.log)\n", .{ path, path });
    }
    try out.flush();

    const status = exitStatus(args.listen, args.report_only, c, exit_failures);
    if (status != 0) std.process.exit(status);
}

/// Verify mode (verify.zig): the tests named by `args.verify`'s prefixes,
/// batched and alone; the report, the result file, and the exit status - 1
/// when any test's verification failed or no prefix named a test.
/// The entry of `list` that declares the test `test_name`, if any.
fn declaredIn(list: []const Declared, test_name: []const u8) ?Declared {
    for (list) |declared| if (std.mem.eql(u8, declared.name, test_name)) return declared;
    return null;
}

fn runVerify(gpa: std.mem.Allocator, io: Io, arena: std.mem.Allocator, out: *Io.Writer, name: []const u8, md: child_mod.Metadata, args: Args, executor: *child_mod.Executor, jobs: u32) !u8 {
    var tests: std.ArrayList(u32) = .empty;
    var unmatched: u32 = 0;
    for (args.verify) |prefix| {
        var matched = false;
        for (md.names, md.expects_panic, 0..) |n, panics, i| {
            if (panics or !std.mem.startsWith(u8, n, prefix)) continue;
            matched = true;
            // Excluded from the ThreadSanitizer variant (`--tsan-skip`): not
            // verified under it either, and said so.
            if (args.sanitize_thread) if (declaredIn(args.tsan_skip, n)) |declared| {
                try out.print("test_launcher: {s} [ThreadSanitizer]: verify: SKIPPED, not run under ThreadSanitizer: {s}: {s}\n", .{ name, n, declared.reason });
                continue;
            };
            if (std.mem.indexOfScalar(u32, tests.items, @intCast(i)) == null) try tests.append(arena, @intCast(i));
        }
        if (!matched) {
            unmatched += 1;
            try out.print("test_launcher: {s}: verify: no test of this executable starts with \"{s}\" (a file with no test blocks is not verified)\n", .{ name, prefix });
        }
    }
    const options: verify_mod.Options = .{ .batched = args.verify_batched, .alone = args.verify_alone, .jobs = jobs };
    try out.print("test_launcher: {s}{s}: verify {d} tests from {d} files: {d} times in one process, {d} times each alone\n", .{
        name,            if (args.sanitize_thread) " [ThreadSanitizer]" else "",
        tests.items.len, args.verify.len,
        options.batched, options.alone,
    });
    try out.flush();
    var v = try verify_mod.Verify.init(gpa, io, executor.executor(), tests.items, options);
    defer v.deinit();
    try v.execute();
    try v.writeReport(out, md.names);
    const failed = v.failures();
    try out.print("test_launcher: {s}: verify: {d} of {d} tests PASS, {d} FAIL; {d} processes\n", .{
        name, tests.items.len - failed, tests.items.len, failed, v.processes.load(.monotonic),
    });
    if (args.out) |path| {
        var aw: Io.Writer.Allocating = .init(arena);
        for (tests.items, v.outcomes) |t, o| {
            try aw.writer.writeAll("{\"test\":");
            try std.json.Stringify.value(md.names[t], .{}, &aw.writer);
            try aw.writer.print(",\"verify\":\"{s}\",\"batched\":[{d},{d}],\"alone\":[{d},{d}]", .{
                if (o.passed(options)) "PASS" else "FAIL", o.batched_ok, options.batched, o.alone_ok, options.alone,
            });
            if (o.first_bad) |bad| try aw.writer.print(",\"first_failure\":{{\"phase\":\"{t}\",\"run\":{d},\"status\":\"{t}\"}}", .{ bad.phase, bad.run, bad.status });
            try aw.writer.writeAll("}\n");
        }
        if (std.fs.path.dirname(path)) |dir| try Io.Dir.cwd().createDirPath(io, dir);
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = aw.written() });
        try out.print("  results: {s}\n", .{path});
    }
    return if (failed != 0 or (tests.items.len == 0 and unmatched != 0)) 1 else 0;
}

/// The launcher's exit status. In server mode the verdicts reached the build
/// runner test by test, and what has no test to blame fails the step here: a
/// child that exited non-zero after `exit`, and a test the launcher could
/// not run (LAUNCHER-ERROR, answered `skip`: the build runner then reports
/// the step failed, "test process unexpectedly exited with code 1", with the
/// launcher's account of the cause). By hand, any non-pass fails the run.
/// `--report-only` fails only for the launcher's own failure: a variant's
/// findings - the tests' verdicts and an exit after the last test - are
/// printed and recorded, not failed.
fn exitStatus(listen: bool, report_only: bool, c: sched.Run.Counts, exit_failures: u32) u8 {
    if (c.launcher_error != 0) return 1;
    if (report_only) return 0;
    if (exit_failures != 0) return 1;
    if (!listen and c.bad() != 0) return 1;
    return 0;
}

test "exit status: a launcher error fails the run in server mode too, where a test's failure does not" {
    // Server mode: failures went to the build runner as failures.
    try testing.expectEqual(@as(u8, 0), exitStatus(true, false, .{ .pass = 3, .fail = 1, .flaky = 1 }, 0));
    try testing.expectEqual(@as(u8, 1), exitStatus(true, false, .{ .pass = 3, .launcher_error = 1 }, 0));
    try testing.expectEqual(@as(u8, 1), exitStatus(true, false, .{ .pass = 3 }, 1));
    try testing.expectEqual(@as(u8, 0), exitStatus(true, false, .{ .pass = 3, .skip = 2 }, 0));
    // By hand: any non-pass.
    try testing.expectEqual(@as(u8, 1), exitStatus(false, false, .{ .pass = 3, .fail = 1 }, 0));
    try testing.expectEqual(@as(u8, 1), exitStatus(false, false, .{ .pass = 3, .launcher_error = 1 }, 0));
    try testing.expectEqual(@as(u8, 0), exitStatus(false, false, .{ .pass = 3, .skip = 1 }, 0));
    // Report-only: only the launcher's own failure fails.
    try testing.expectEqual(@as(u8, 0), exitStatus(false, true, .{ .pass = 3, .fail = 1, .flaky = 2 }, 0));
    try testing.expectEqual(@as(u8, 0), exitStatus(true, true, .{ .pass = 3 }, 1));
    try testing.expectEqual(@as(u8, 1), exitStatus(true, true, .{ .pass = 3, .launcher_error = 1 }, 0));
}

/// A failure of the launcher itself, outside any test (it could not list
/// the tests, open the slot directory, write the results): printed with its
/// cause as an `error: '<step>' failed:` line (the form gate scripts grep,
/// as `report.writeLauncherErrors`), and the run fails - in server mode,
/// the step, with no test blamed. `args` starts with the suite's name.
fn launcherFailure(out: *Io.Writer, comptime what: []const u8, args: anytype) noreturn {
    out.print("error: 'test {s}' failed: LAUNCHER-ERROR: " ++ what ++ "\n", args) catch {};
    out.flush() catch {};
    std.process.exit(1);
}

/// The result file (one JSON line per test, `report.writeLine`) and, beside
/// it, `<path>.log`: the output of every test that did not pass.
fn writeResults(io: Io, arena: std.mem.Allocator, path: []const u8, names: []const []const u8, plan: *const plan_mod.Plan, run: *const sched.Run, seed: u64) !void {
    var aw: Io.Writer.Allocating = .init(arena);
    for (0..run.batchCount()) |k| {
        for (plan.batchTests(run.batchId(@intCast(k)))) |t| {
            try report.writeLine(&aw.writer, names[t], t, &run.records[t], seed);
        }
    }
    if (std.fs.path.dirname(path)) |dir| try Io.Dir.cwd().createDirPath(io, dir);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = aw.written() });
    var log: Io.Writer.Allocating = .init(arena);
    for (0..run.batchCount()) |k| {
        for (plan.batchTests(run.batchId(@intCast(k)))) |t| {
            const rec = &run.records[t];
            if (rec.verdict.ok()) continue;
            try log.writer.print("=== {s} {s} (batch {d} position {d}, seed 0x{x})\n{s}{s}\n", .{
                rec.verdict.label(), names[t], rec.batch, rec.position, seed, rec.cause, rec.output,
            });
        }
    }
    const log_path = try std.fmt.allocPrint(arena, "{s}.log", .{path});
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = log_path, .data = log.written() });
}
