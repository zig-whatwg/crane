//! The Crane test runner: every test executable `zig build test` builds runs
//! its tests through it (build.zig, `useCraneTestRunner`).
//!
//! It is Zig's own runner (lib/zig/compiler/test_runner.zig of the pinned
//! 0.17 toolchain: the server mode the build runner and tools/test_launcher
//! speak, and the terminal mode for a bare run), with one addition around
//! each test: the process-state check of the approved test plan
//! (tmp/plans/test-architecture-recommendation.md section 3,
//! tmp/plans/test-launcher-design.md sections 2 and 3). Before the test it
//! takes a digest of the process's state (state.zig); after it, it takes
//! another and compares them. A field that changed is logged naming the
//! field - with `std.log.err` where the suite's checks fail tests, so the
//! test that changed it fails by name (Chromium's base::TestSuite checks
//! after every test, Gecko's leaked-window checks blamed on their test);
//! with `std.log.warn` where the suite is report-only.
//!
//! The protocol is unchanged: no message carries the digest. stderr and
//! `log_err_count` do, and the launcher keeps the text of every test that
//! did not pass.
//!
//! Poison on free (poisoning.zig, lane poison2): every test's
//! std.testing.allocator is made with SafeAllocator's
//! `check_write_after_free`, which writes 0x55 over what a test frees, and a
//! test's own DebugAllocator is `poisoning.DebugAllocator`, reached through
//! this file (`@import("root").poisoning`). `CRANE_POISON_FREES=0` turns both
//! off for a run (`poison_frees`).
//!
//! The many-Browsers variant (CRANE_TEST_MANY_BROWSERS=1, which
//! tools/test_launcher's --many-browsers sets; build.zig -Dmany-browsers):
//! from the first test on, a second, busy Browser works on another thread of
//! the process (neighbour.zig, busy_browser.zig). The runner holds it between
//! two of its iterations while it takes each digest, so the check compares
//! the process as it would without it, and fails the test during which the
//! busy Browser failed (`std.log.err`, naming it). Its log lines reach
//! `log` too, so an error it logs fails the test it ran beside.
//!
//! Not a test file: build.zig copies this directory beside the suite's
//! generated `suite.zig` and points the executable's `test_runner` here.

const builtin = @import("builtin");
const std = @import("std");
const Io = std.Io;
const testing = std.testing;
const panic = std.debug.panic;
const state = @import("state.zig");
const neighbour_mod = @import("neighbour.zig");
const busy_browser = @import("busy_browser.zig");
const suite = @import("suite.zig");

/// Poison on free, for every allocator a test checks memory with: a test
/// file reaches it as `@import("root").poisoning` - its `DebugAllocator` is
/// the one a test makes for itself (a Browser per thread in a race test).
pub const poisoning = @import("poisoning.zig");

// process-wide: decided once, in `main`, from CRANE_POISON_FREES, before the
// first test and the first thread, and only read after - by each test's
// std.testing.allocator (`initTestAllocator`) and by every
// `poisoning.DebugAllocator` (`poisoning.processPoisons`), the busy Browser's
// on its own thread included.
/// Whether this process poisons what its tests free (`poisoning.enabled`).
pub var poison_frees: bool = poisoning.by_default;

pub const std_options: std.Options = .{
    .logFn = log,
    .log_level = compiled_log_level,
};

/// -Dtest-log-level (build.zig, useCraneTestRunner), or null. Public for
/// tests/infra/test_log_level_test.zig, which pins the defaults below.
pub const test_log_level_option: ?std.log.Level = suite.log_level_option;

/// The level below which every `std.log` call is compiled out: .info unless
/// -Dtest-log-level says otherwise. A Debug build's default, .debug, analyses
/// and emits every `log.debug` site - hundreds, many in the generic binding
/// code - in every test executable, for output the runner never prints (lane
/// compiletime1).
const compiled_log_level: std.log.Level = test_log_level_option orelse .info;

/// The level the runner prints at while a test runs (`testing.log_level`,
/// which a test may lower): .warn, or -Dtest-log-level's level, so a local
/// diagnosis built with -Dtest-log-level=debug prints its debug logs.
const printed_log_level: std.log.Level = test_log_level_option orelse .warn;

/// Atomic: the many-Browsers variant's busy Browser logs from its own thread.
var log_err_count: std.atomic.Value(usize) = .init(0);
var fba: std.heap.FixedBufferAllocator = .init(&fba_buffer);
var fba_buffer: [8192]u8 = undefined;
var stdin_buffer: [4096]u8 = undefined;
var stdout_buffer: [4096]u8 = undefined;
var stdin_reader: Io.File.Reader = undefined;
var stdout_writer: Io.File.Writer = undefined;
const runner_threaded_io: Io = Io.Threaded.global_single_threaded.io();

/// The many-Browsers variant's busy Browser, when the environment asks for
/// it (`configureNeighbour`); started before the first test runs.
var neighbour: neighbour_mod.Neighbour = .init(runner_threaded_io, .{ .iterate = busy_browser.iterate });
var neighbour_wanted = false;

comptime {
    // Zig's backends that need the simple runner (std's `need_simple`) are
    // not Crane's: every Crane test executable is built by LLVM.
    switch (builtin.zig_backend) {
        .stage2_aarch64, .stage2_loongarch, .stage2_powerpc, .stage2_riscv64 => @compileError("the Crane test runner needs the LLVM backend"),
        else => {},
    }
    if (builtin.fuzz) @compileError("fuzzing runs under Zig's own test runner; build without the Crane test runner");
}

pub fn main(init: std.process.Init.Minimal) void {
    // The engine's part of the process start is `startEngineOnce`: before
    // the first test and before any thread exists, never here - a process
    // the launcher only asks for its tests' names runs no test and starts no
    // engine. How many threads the process has now is what it must still
    // have then.
    if (suite.engine != null) threads_at_main = threadCount();
    const args = init.args.toSlice(fba.allocator()) catch |err| panic("unable to parse command line args: {t}", .{err});

    var listen = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--listen=-")) {
            listen = true;
        } else if (std.mem.startsWith(u8, arg, "--seed=")) {
            testing.random_seed = std.fmt.parseUnsigned(u32, arg["--seed=".len..], 0) catch
                @panic("unable to parse --seed command line argument");
        } else if (std.mem.startsWith(u8, arg, "--cache-dir")) {
            // Only fuzzing reads it.
        } else {
            panic("unrecognized command line argument: {s}", .{arg});
        }
    }

    poison_frees = poisoning.enabled(init.environ.getPosix(poisoning.env_var));
    state.configure(init.environ);
    configureNeighbour(init.environ);

    if (listen) {
        return mainServer(init) catch |err| panic("internal test runner failure: {t}", .{err});
    } else {
        return mainTerminal(init);
    }
}

/// Whether `startEngineOnce` has run.
var engine_start_done = false;

/// The process start's engine step, done once, before the process's first
/// test and before any thread exists - a test's, the busy Browser's, V8's
/// own workers: the engine's per-process state that only threads created
/// after it inherit (engine protocol initializeBeforeThreadCreation; V8's
/// thread isolation key on x86-64 Linux), as every Crane host's main does
/// first. A suite's tests start V8 on whichever thread comes first, and
/// every thread then has access. So a test may assume it, as it may assume
/// anything the process start makes; nothing the runner does before its
/// first test starts a thread (its own Io is single-threaded, and the
/// terminal mode's progress thread starts after this).
///
/// Before the first test, not first in `main`: the launcher's listing run -
/// the process it asks only for its tests' names (tools/test_launcher
/// child.zig, `queryMetadata`) - runs no test, so it starts no engine. That
/// process has the launcher's own environment, none of a test child's: in a
/// -Dsanitize-thread build a V8 started there printed the sanitizer's
/// reports of V8's own worker threads, unsuppressed, into every log (four
/// per listing run; lane build3, 2026-11-13).
///
/// CRANE_TEST_ENGINE_EARLY=0 skips it, as a host that never calls it does:
/// build.zig runs tests-v8's platform start tests that way too
/// (`addEngineLateRun`), so the fallback - V8 without thread isolation,
/// started on a later thread beside others - stays tested.
fn startEngineOnce(environ: std.process.Environ) void {
    if (engine_start_done) return;
    engine_start_done = true;
    const engine = suite.engine orelse return;
    if (!engineEarly(environ)) return;
    // "Before any thread exists" is checked, not assumed: the process has
    // the threads it had when main began (its main thread; whatever else a
    // runtime under it keeps is counted on both sides). A thread started by
    // anything the runner does before its first test would miss the
    // engine's per-process state - V8 would then have to run without thread
    // isolation, or fault - so it fails here, in every test process of every
    // suite that links the engine, by name.
    if (threads_at_main) |at_main| {
        if (threadCount()) |now| {
            if (now != at_main) panic("the test runner started a thread before the engine's process start: {d} thread(s) when main began, {d} before the first test. engine.initializeBeforeThreadCreation must run before any thread exists: start nothing before `startEngineOnce` (tests/test_runner/runner.zig)", .{ at_main, now });
        }
    }
    engine.initializeBeforeThreadCreation();
}

/// How many threads this process has when `main` begins (`threadCount`).
var threads_at_main: ?usize = null;

/// How many threads this process has now: the entries of /proc/self/task.
/// Null where the system has no such listing (macOS) or it cannot be read -
/// the check that uses it is then not made there; the pool's Linux host
/// makes it in every gate.
fn threadCount() ?usize {
    if (builtin.os.tag != .linux) return null;
    var tasks = Io.Dir.cwd().openDir(runner_threaded_io, "/proc/self/task", .{ .iterate = true }) catch return null;
    defer tasks.close(runner_threaded_io);
    var count: usize = 0;
    var entries = tasks.iterate();
    while (entries.next(runner_threaded_io) catch return null) |_| count += 1;
    return count;
}

/// Whether the process start makes the engine's per-process state before any
/// thread (engine.initializeBeforeThreadCreation): unless the environment
/// says CRANE_TEST_ENGINE_EARLY=0.
fn engineEarly(environ: std.process.Environ) bool {
    const value = environ.getPosix("CRANE_TEST_ENGINE_EARLY") orelse return true;
    return !std.mem.eql(u8, value, "0");
}

/// The many-Browsers variant, from the environment the launcher gives its
/// children (tools/test_launcher child.zig, `many_browsers_variable`).
fn configureNeighbour(environ: std.process.Environ) void {
    const value = environ.getPosix("CRANE_TEST_MANY_BROWSERS") orelse return;
    if (value.len == 0 or std.mem.eql(u8, value, "0")) return;
    if (suite.browser == null) {
        // A suite with no Browser to run (no V8, or built without
        // -Dmany-browsers, which adds the browser module): said once per
        // process, and the tests run as usual.
        std.debug.print("test runner ({s}): CRANE_TEST_MANY_BROWSERS is set, but this executable has no Browser (build it with -Dmany-browsers; a suite that links no V8 cannot run one) - the tests run without the busy Browser\n", .{suite.name});
        return;
    }
    neighbour_wanted = true;
}

/// Starts the busy Browser before the first test, not at process start: the
/// launcher's process that only lists the tests never runs one.
fn startNeighbourOnce() void {
    if (!neighbour_wanted or neighbour.running()) return;
    neighbour.start() catch |err| panic("the many-Browsers variant could not start its busy Browser's thread: {t}", .{err});
    // A test's hook override is a statement about the whole process: from its
    // first override to its last restore the busy Browser waits between two
    // iterations, so it neither races the slot's write nor runs on the
    // test's fake (src/dom/hook.zig; Chromium's ScopedFeatureList holds its
    // process-wide override for its scope).
    if (suite.dom) |dom| {
        _ = dom.process_start.observeOverridesForTest(.{
            .ctx = &neighbour,
            .first_made = &neighbour_mod.Neighbour.holdFor,
            .last_restored = &neighbour_mod.Neighbour.releaseFor,
        });
    }
}

/// Ends the busy Browser before the process exits: an exit with the thread
/// mid-iteration would tear the engine down under it.
fn stopNeighbour() void {
    neighbour.stop();
}

/// After a test: whether the busy Browser failed while it ran (called while
/// held). A failure fails the test it ran beside - as a race under
/// ThreadSanitizer is blamed on the running test - naming the busy Browser,
/// so the report says which side failed.
fn checkNeighbour(test_name: []const u8) void {
    if (!neighbour.running()) return;
    const got = neighbour.take();
    const failure = got.failure orelse return;
    std.log.scoped(.many_browsers).err("the busy Browser on another thread failed during {s}: iteration {d}: {t}: {s}{s}", .{
        test_name,
        failure.iteration,
        failure.err,
        failure.message(),
        if (got.more_failures != 0) " (and later iterations failed too)" else "",
    });
}

/// One test, with the state check around it. The digest before is taken
/// after the test's allocator and Io are made and the one after before they
/// end, so neither sees the other's allocations; the digests themselves
/// allocate nothing from the test's allocator. Each digest is taken with
/// the busy Browser held between two of its iterations, when it has
/// nothing alive.
fn runOne(test_fn: std.lang.TestFn, index: u32) anyerror!void {
    startNeighbourOnce();
    neighbour.hold();
    state.before();
    // What failed before this test started (between tests) is not its.
    if (neighbour.running()) _ = neighbour.take();
    neighbour.release();
    const result = test_fn.func();
    neighbour.hold();
    state.after(index, test_fn.name);
    checkNeighbour(test_fn.name);
    neighbour.release();
    return result;
}

/// A test's std.testing.allocator, made before each test and checked for
/// leaks after it: Zig's own runner's SafeAllocator, canary and all, with
/// `check_write_after_free` - its free writes 0x55 over every allocation in
/// a bucket and its bucket release checks nothing wrote after - unless
/// CRANE_POISON_FREES=0 (`poison_frees`). Larger allocations are unmapped
/// when freed either way.
fn initTestAllocator() void {
    testing.allocator_instance = .init(std.heap.page_allocator, .{
        .canary = 0xc3a701ba,
        .check_write_after_free = poison_frees,
    });
}

fn mainServer(init: std.process.Init.Minimal) !void {
    stdin_reader = .initStreaming(.stdin(), runner_threaded_io, &stdin_buffer);
    stdout_writer = .initStreaming(.stdout(), runner_threaded_io, &stdout_buffer);
    var server: std.zig.Server = .{
        .in = &stdin_reader.interface,
        .out = &stdout_writer.interface,
    };
    try server.serveStringMessage(.zig_version, builtin.zig_version_string);

    while (true) {
        const hdr = try server.receiveMessage();
        switch (hdr.tag) {
            .exit => {
                stopNeighbour();
                return std.process.exit(0);
            },
            .query_test_metadata => {
                var sa: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});
                defer if (sa.deinit() != 0) @panic("internal test runner memory leak");
                const gpa = sa.allocator();

                var string_bytes: std.ArrayList(u8) = .empty;
                defer string_bytes.deinit(gpa);
                try string_bytes.append(gpa, 0); // Reserve 0 for null.

                const test_fns = builtin.test_functions;
                const names = try gpa.alloc(u32, test_fns.len);
                defer gpa.free(names);
                const expected_panic_msgs = try gpa.alloc(u32, test_fns.len);
                defer gpa.free(expected_panic_msgs);

                for (test_fns, names, expected_panic_msgs) |test_fn, *name, *expected_panic_msg| {
                    name.* = @intCast(string_bytes.items.len);
                    try string_bytes.ensureUnusedCapacity(gpa, test_fn.name.len + 1);
                    string_bytes.appendSliceAssumeCapacity(test_fn.name);
                    string_bytes.appendAssumeCapacity(0);
                    expected_panic_msg.* = 0;
                }

                try server.serveTestMetadata(.{
                    .names = names,
                    .expected_panic_msgs = expected_panic_msgs,
                    .string_bytes = string_bytes.items,
                });
            },

            .run_test => {
                // The first test of the process: the engine's process start,
                // before anything of the test exists.
                startEngineOnce(init.environ);
                testing.environ = init.environ;
                initTestAllocator();
                testing.io_instance = .init(testing.allocator, .{
                    .argv0 = .init(init.args),
                    .environ = init.environ,
                });
                log_err_count.store(0, .monotonic);
                const index = try server.receiveBody_u32();
                const test_fn = builtin.test_functions[index];

                // let the build server know we're starting the test now
                try server.serveStringMessage(.test_started, &.{});

                const TestResults = std.zig.Server.Message.TestResults;
                const status: TestResults.Status = if (runOne(test_fn, index)) |v| s: {
                    v;
                    break :s .pass;
                } else |err| switch (err) {
                    error.SkipZigTest => .skip,
                    else => s: {
                        if (@errorReturnTrace()) |trace| {
                            std.debug.dumpErrorReturnTrace(trace);
                        }
                        break :s .fail;
                    },
                };
                testing.io_instance.deinit();
                const leak_count = testing.allocator_instance.deinit();
                try server.serveTestResults(.{
                    .index = index,
                    .flags = .{
                        .status = status,
                        .fuzz = false,
                        .log_err_count = std.math.lossyCast(
                            @FieldType(TestResults.Flags, "log_err_count"),
                            log_err_count.load(.monotonic),
                        ),
                        .leak_count = std.math.lossyCast(
                            @FieldType(TestResults.Flags, "leak_count"),
                            leak_count,
                        ),
                    },
                });
            },

            else => {
                std.debug.print("unsupported message: {x}\n", .{@backingInt(hdr.tag)});
                std.process.exit(1);
            },
        }
    }
}

fn mainTerminal(init: std.process.Init.Minimal) void {
    // Every test runs in this process: the engine's process start, before
    // the progress display starts its thread.
    startEngineOnce(init.environ);
    const test_fn_list = builtin.test_functions;
    var ok_count: usize = 0;
    var skip_count: usize = 0;
    var fail_count: usize = 0;
    const root_node = std.Progress.start(runner_threaded_io, .{
        .root_name = "Test",
        .estimated_total_items = test_fn_list.len,
    });
    const have_tty = Io.File.stderr().isTty(runner_threaded_io) catch unreachable;

    var leaks: usize = 0;
    for (test_fn_list, 0..) |test_fn, i| {
        initTestAllocator();
        testing.io_instance = .init(testing.allocator, .{
            .argv0 = .init(init.args),
            .environ = init.environ,
        });
        defer {
            testing.io_instance.deinit();
            if (testing.allocator_instance.deinit() != 0) leaks += 1;
        }
        testing.log_level = printed_log_level;
        testing.environ = init.environ;

        const test_node = root_node.start(test_fn.name, 0);
        if (!have_tty) {
            std.debug.print("{d}/{d} {s}...", .{ i + 1, test_fn_list.len, test_fn.name });
        }
        if (runOne(test_fn, @intCast(i))) |_| {
            ok_count += 1;
            test_node.end();
            if (!have_tty) std.debug.print("OK\n", .{});
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip_count += 1;
                if (have_tty) {
                    std.debug.print("{d}/{d} {s}...SKIP\n", .{ i + 1, test_fn_list.len, test_fn.name });
                } else {
                    std.debug.print("SKIP\n", .{});
                }
                test_node.end();
            },
            else => {
                fail_count += 1;
                if (have_tty) {
                    std.debug.print("{d}/{d} {s}...FAIL ({t})\n", .{
                        i + 1, test_fn_list.len, test_fn.name, err,
                    });
                } else {
                    std.debug.print("FAIL ({t})\n", .{err});
                }
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpErrorReturnTrace(trace);
                }
                test_node.end();
            },
        }
    }
    root_node.end();
    stopNeighbour();
    if (ok_count == test_fn_list.len) {
        std.debug.print("All {d} tests passed.\n", .{ok_count});
    } else {
        std.debug.print("{d} passed; {d} skipped; {d} failed.\n", .{ ok_count, skip_count, fail_count });
    }
    const errors_logged = log_err_count.load(.monotonic);
    if (errors_logged != 0) {
        std.debug.print("{d} errors were logged.\n", .{errors_logged});
    }
    if (leaks != 0) {
        std.debug.print("{d} tests leaked memory.\n", .{leaks});
    }
    if (leaks != 0 or errors_logged != 0 or fail_count != 0) {
        std.process.exit(1);
    }
}

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@backingInt(message_level) <= @backingInt(std.log.Level.err)) {
        _ = log_err_count.fetchAdd(1, .monotonic);
    }
    // The busy Browser's thread prints at warn and above, marked, and never
    // reads `testing.log_level`, which a test may set while it runs.
    if (neighbour.isOwnThread()) {
        if (@backingInt(message_level) <= @backingInt(std.log.Level.warn)) std.debug.print(
            "[busy Browser] [" ++ @tagName(scope) ++ "] (" ++ @tagName(message_level) ++ "): " ++ format ++ "\n",
            args,
        );
        return;
    }
    if (@backingInt(message_level) <= @backingInt(testing.log_level)) {
        std.debug.print(
            "[" ++ @tagName(scope) ++ "] (" ++ @tagName(message_level) ++ "): " ++ format ++ "\n",
            args,
        );
    }
}

/// `std.testing.fuzz` reaches the runner through `@import("root").fuzz`.
/// Outside a fuzzing build - the only builds this runner serves - Zig's own
/// runner runs the corpus and the empty input once each; so does this.
pub fn fuzz(
    context: anytype,
    comptime testOne: fn (context: @TypeOf(context), *std.testing.Smith) anyerror!void,
    options: testing.FuzzInputOptions,
) anyerror!void {
    for (options.corpus) |input| {
        var smith: testing.Smith = .{ .in = input };
        try testOne(context, &smith);
    }
    var smith: testing.Smith = .{ .in = "" };
    try testOne(context, &smith);
}
