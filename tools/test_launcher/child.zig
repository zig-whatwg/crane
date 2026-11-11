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
const builtin = @import("builtin");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const InMessage = std.zig.Server.Message;
const sched = @import("scheduler.zig");
const Slots = @import("slots.zig").Slots;
/// tests/test_runner/poisoning.zig: the CRANE_POISON_FREES switch the Crane
/// test runner reads, so the launcher reads it the same way.
const poisoning = @import("poisoning");

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

    /// The environment of every child: `testEnvironment` of the launcher's
    /// (main.zig). Null: the launcher's own, unchanged.
    environ_map: ?*const std.process.Environ.Map = null,
    /// Tests declared alone (indexed by test index; shorter than the test
    /// count means "not alone"), and the environment of a process that runs
    /// any of them: `environ_map` without the many-Browsers variable, so no
    /// busy Browser runs beside it (main.zig, `--alone`).
    alone: []const bool = &.{},
    alone_environ_map: ?*const std.process.Environ.Map = null,

    pub fn init(gpa: Allocator, io: Io, argv: []const []const u8, test_timeout_ns: u64, jobs: u32) !Executor {
        const procs = try gpa.alloc(?*Proc, @max(jobs, 1));
        errdefer gpa.free(procs);
        @memset(procs, null);
        const held = try gpa.alloc(?Slots.Slot, procs.len);
        @memset(held, null);
        return .{ .gpa = gpa, .io = io, .argv = argv, .test_timeout_ns = test_timeout_ns, .procs = procs, .held = held };
    }

    /// The environment of a process that will run `tests`: without the busy
    /// Browser when any of them is declared alone.
    pub fn environFor(e: *const Executor, tests: []const u32) ?*const std.process.Environ.Map {
        for (tests) |t| {
            if (t < e.alone.len and e.alone[t]) return e.alone_environ_map;
        }
        return e.environ_map;
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

    fn start(ptr: *anyopaque, w: u32, tests: []const u32, diag: *Io.Writer) anyerror!void {
        const e: *Executor = @ptrCast(@alignCast(ptr));
        std.debug.assert(e.procs[w] == null);
        if (e.slots) |slots| {
            std.debug.assert(e.held[w] == null);
            var failed: u32 = 0;
            e.held[w] = slots.acquire(&failed) catch |err| {
                diag.print("could not take a test-process slot, {s}/slot-{d}: {f}", .{ slots.path, failed, FmtError{ .err = err } }) catch {};
                return err;
            };
        }
        errdefer e.releaseSlot(w);
        const p = try e.gpa.create(Proc);
        errdefer e.gpa.destroy(p);
        p.child = std.process.spawn(e.io, .{
            .argv = e.argv,
            .stdin = .pipe,
            .stdout = .pipe,
            .stderr = .pipe,
            .environ_map = e.environFor(tests),
            .request_resource_usage_statistics = true,
        }) catch |err| {
            // Whether the executable is there now tells a path that was
            // never right from one replaced while the launcher ran.
            const now: []const u8 = if (Io.Dir.cwd().statFile(e.io, e.argv[0], .{})) |_| "it is there now" else |stat_err| switch (stat_err) {
                error.FileNotFound => "it is not there now",
                else => "it cannot be read now",
            };
            diag.print("could not spawn {s}: {f}; {s}", .{ e.argv[0], FmtError{ .err = err }, now }) catch {};
            return err;
        };
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
                    // Everything the test printed came before its result,
                    // but may still be in the pipe (`readReady`): read it
                    // now, so that it is this test's output - and, when the
                    // test passed, not the next one's.
                    readReady(&p.mr);
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
            // What it printed after its last result - while it exited - kept
            // past the reader's end for the report below.
            var printed_buf: [exit_report_tail]u8 = undefined;
            const printed = tail(&printed_buf, p.mr.reader(1).buffered());
            p.mr.deinit();
            term = p.child.wait(io) catch null;
            if (how == .exit) {
                if (term) |tm| if (!tm.success()) {
                    _ = e.exit_failures.fetchAdd(1, .monotonic);
                    var line_buf: [exit_report_tail + 256]u8 = undefined;
                    log.warn("{s}", .{exitFailureReport(&line_buf, tm, printed)});
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

/// Reads into `mr`'s buffers whatever its pipes hold now, without waiting.
///
/// A test process prints a failing test's text on stderr and THEN sends its
/// test_results on stdout, but that order does not reach the launcher's
/// buffers: the multi-reader polls both pipes and reads those poll found
/// ready. When poll finds only stdout ready - the test_started message - and
/// the launcher's thread is preempted before the read (a loaded host), the
/// process can print its text and send its result in the meantime; the read
/// then takes both messages, and the text stays in the stderr pipe, unread.
/// The result was read with an empty output (tools/test_launcher's own
/// fixture test, under v8state1's gate load, 2026-11-02), and the text would
/// have been read with the NEXT test's. Everything written to stderr before
/// the result is in the pipe by the time the result is read, so a poll that
/// does not wait finds it; read until the pipes have nothing ready. Bounded
/// for a process that never stops printing (a busy Browser's thread): what
/// it prints later belongs to no test in particular.
fn readReady(mr: *Io.File.MultiReader) void {
    const now: Io.Timeout = .{ .duration = .{ .clock = .awake, .raw = .zero } };
    for (0..max_ready_reads) |_| {
        // Timeout: nothing ready; EndOfStream: every pipe closed.
        mr.fill(64, now) catch return;
    }
}

/// `readReady`'s bound: reads of what the pipes hold at once.
const max_ready_reads = 1024;

fn elapsed(io: Io, from: Io.Clock.Timestamp) u64 {
    return @intCast(@max(from.untilNow(io).raw.nanoseconds, 0));
}

/// An error by its name and, where it has one, the errno it stands for:
/// "FileNotFound (ENOENT)".
pub const FmtError = struct {
    err: anyerror,

    pub fn format(f: FmtError, w: *Io.Writer) Io.Writer.Error!void {
        try w.writeAll(@errorName(f.err));
        const errno: ?[]const u8 = switch (f.err) {
            error.FileNotFound => "ENOENT",
            error.AccessDenied => "EACCES",
            error.PermissionDenied => "EPERM",
            error.NotDir => "ENOTDIR",
            error.IsDir => "EISDIR",
            error.PathAlreadyExists => "EEXIST",
            error.NameTooLong => "ENAMETOOLONG",
            error.FileBusy => "ETXTBSY",
            error.ProcessFdQuotaExceeded => "EMFILE",
            error.SystemFdQuotaExceeded => "ENFILE",
            error.NoSpaceLeft => "ENOSPC",
            error.SymLinkLoop => "ELOOP",
            else => null,
        };
        if (errno) |n| try w.print(" ({s})", .{n});
    }
};

const log = std.log.scoped(.test_launcher);

/// The most of what a process printed while exiting that a report keeps:
/// its last bytes, where a fatal check or a sanitizer names itself.
const exit_report_tail = 2048;

/// The last `buf.len` bytes of `text`, copied into `buf`.
fn tail(buf: []u8, text: []const u8) []const u8 {
    const kept = text[text.len -| buf.len..];
    @memcpy(buf[0..kept.len], kept);
    return buf[0..kept.len];
}

/// The line `finish` logs for a test process that exited non-zero after its
/// tests passed and it was asked to exit (Chromium's TEST_FAILURE_ON_EXIT):
/// how it ended - the exit code or the signal - and what it printed while
/// exiting. main.zig's count alone said neither (lane v8up b3c: an after-exit
/// flake on V8 15.7 under load, page_realm_operations_test).
/// `printed` is at most `exit_report_tail` bytes (`tail`); a `buf` too small
/// for the line gives an empty one.
fn exitFailureReport(buf: []u8, term: std.process.Child.Term, printed: []const u8) []const u8 {
    return std.fmt.bufPrint(buf, "test process {f} after exit; it printed while exiting ({d} bytes): {s}", .{
        FmtTerm{ .term = term },
        printed.len,
        if (printed.len == 0) "nothing" else printed,
    }) catch buf[0..0];
}

const FmtTerm = struct {
    term: ?std.process.Child.Term,
    pub fn format(f: FmtTerm, w: *Io.Writer) Io.Writer.Error!void {
        if (f.term) |t| return t.format(w);
        try w.writeAll("ended (status unknown)");
    }
};

/// The time zone and locale every test child runs in, whatever the shell
/// that started the build had: WebKit's harness fixes them the same way
/// (webkitpy port/base.py forces TZ=US/Pacific - "Some tests fail if the
/// time zone is not set to US/Pacific", webkit.org/b/186612 - and copies
/// only a whitelist of the environment to its drivers). Pinned here, not in
/// the `testing` platform: WPT runs keep the host's environment.
pub const fixed_environment = [_][2][]const u8{
    .{ "TZ", "America/Los_Angeles" },
    .{ "LANG", "en_US.UTF-8" },
    .{ "LC_ALL", "en_US.UTF-8" },
};

/// The proxy settings no test child sees: a test that reaches the network
/// reaches its own test servers directly, on every host.
pub const cleared_environment = [_][]const u8{
    "http_proxy", "https_proxy", "all_proxy", "no_proxy",
    "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
};

/// libc's own poisoning of what it frees, set for every test child (lane
/// poison2): the memory no Zig allocator of a test sees - v8_wrapper.cpp's
/// new and delete, std.heap.c_allocator - gets what std.testing.allocator's
/// SafeAllocator does to Zig memory (tests/test_runner/poisoning.zig), so a
/// read after a C++ delete reads poison instead of the old object.
///
/// - macOS libmalloc, `MallocScribble=1` (malloc(3)): a freed block is filled
///   with 0x55 and a new one with 0xaa. Measured on chat.local (macOS 27.0.1):
///   its malloc already zeroes a freed block of up to at least 4 KiB beyond
///   its free-list header, scribble or not, so there the scribble's work is
///   the larger blocks (16 KiB and up, which keep their bytes without it) and
///   the 0xaa in every new block (a read before a write reads 0xaa, not 0).
/// - glibc, `MALLOC_PERTURB_=85` (mallopt(3), M_PERTURB): a freed block is
///   filled with 85 (0x55, as macOS) and a new one, except calloc's, with
///   its complement (0xaa). Ignored by a libc without it (musl).
///
/// Off, with the rest of the poisoning, when the launcher's environment has
/// CRANE_POISON_FREES=0 (`testEnvironment`). Under ThreadSanitizer its own
/// allocator replaces libc's, so neither variable does anything there.
pub const malloc_scribble: ?[2][]const u8 = switch (builtin.os.tag) {
    .macos, .ios, .tvos, .watchos, .visionos => .{ "MallocScribble", "1" },
    .linux => .{ "MALLOC_PERTURB_", "85" },
    else => null,
};

/// The variable that turns on the Crane test runner's many-Browsers variant
/// (tests/test_runner/neighbour.zig): a second, busy Browser on another
/// thread of every test process.
pub const many_browsers_variable = "CRANE_TEST_MANY_BROWSERS";

/// What a run adds to every test child's environment.
pub const EnvironmentOptions = struct {
    /// The test executable is built with ThreadSanitizer (-Dsanitize-thread):
    /// TSAN_OPTIONS makes the first race a crash of the process
    /// (`halt_on_error=1`) - so the launcher blames the test that was
    /// running, as it blames any crash - where by default a race only
    /// changes the exit status at `exit`, with no test to blame.
    sanitize_thread: ?SanitizeThread = null,
    /// The many-Browsers variant (`many_browsers_variable`).
    many_browsers: bool = false,

    pub const SanitizeThread = struct {
        /// The suppression file: only proven false positives of the
        /// uninstrumented V8 (tools/test_launcher/tsan_suppressions.txt).
        suppressions: ?[]const u8 = null,
    };
};

/// TSAN_OPTIONS: the launcher's flags, then any the launcher was given in
/// its own environment, which come later and so win (a run by hand with
/// TSAN_OPTIONS=history_size=7 keeps it).
fn tsanOptions(gpa: Allocator, tsan: EnvironmentOptions.SanitizeThread, own: ?[]const u8) Allocator.Error![]u8 {
    var aw: Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    const w = &aw.writer;
    w.writeAll("halt_on_error=1:second_deadlock_stack=1") catch return error.OutOfMemory;
    if (tsan.suppressions) |path| w.print(":suppressions={s}", .{path}) catch return error.OutOfMemory;
    if (own) |text| if (text.len != 0) w.print(":{s}", .{text}) catch return error.OutOfMemory;
    return aw.toOwnedSlice();
}

/// The environment of every test child: `base` (the launcher's), with
/// `fixed_environment` set and `cleared_environment` removed, libc's
/// scribbling (`malloc_scribble`) unless `base` turns poisoning off
/// (CRANE_POISON_FREES=0, which the child's test runner reads too), and what
/// `options` adds. The caller owns the result; `base` is not changed.
pub fn testEnvironment(gpa: Allocator, base: *const std.process.Environ.Map, options: EnvironmentOptions) Allocator.Error!std.process.Environ.Map {
    var env = try base.clone(gpa);
    errdefer env.deinit();
    for (fixed_environment) |pair| try env.put(pair[0], pair[1]);
    for (cleared_environment) |name| _ = env.swapRemove(name);
    if (malloc_scribble) |pair| {
        if (poisoning.enabled(base.get(poisoning.env_var))) try env.put(pair[0], pair[1]) else _ = env.swapRemove(pair[0]);
    }
    if (options.sanitize_thread) |tsan| {
        const value = try tsanOptions(gpa, tsan, base.get("TSAN_OPTIONS"));
        defer gpa.free(value);
        try env.put("TSAN_OPTIONS", value);
    }
    if (options.many_browsers) try env.put(many_browsers_variable, "1");
    return env;
}

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

test "a process that runs a test declared alone gets the environment without the busy Browser" {
    var e = try Executor.init(testing.allocator, testing.io, &.{"x"}, 10, 1);
    defer e.deinit();
    var many: std.process.Environ.Map = .init(testing.allocator);
    defer many.deinit();
    var alone_env: std.process.Environ.Map = .init(testing.allocator);
    defer alone_env.deinit();
    e.environ_map = &many;
    e.alone_environ_map = &alone_env;
    const alone = [_]bool{ false, true, false };
    e.alone = &alone;
    try testing.expectEqual(@as(?*const std.process.Environ.Map, &many), e.environFor(&.{ 0, 2 }));
    try testing.expectEqual(@as(?*const std.process.Environ.Map, &alone_env), e.environFor(&.{1}));
    // A process that runs it among others has none either (verify's batched
    // phase), and one past the list is not alone.
    try testing.expectEqual(@as(?*const std.process.Environ.Map, &alone_env), e.environFor(&.{ 0, 1, 2 }));
    try testing.expectEqual(@as(?*const std.process.Environ.Map, &many), e.environFor(&.{7}));
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

/// A worker's process faked with three pipes, for `Executor.run`: the
/// launcher's ends are the Proc's, as `start` sets them up; the test writes
/// the child's side. `run`'s success path never touches `child`.
const PipedProc = struct {
    p: *Proc,
    stdin: [2]std.posix.fd_t,
    stdout: [2]std.posix.fd_t,
    stderr: [2]std.posix.fd_t,

    fn file(fd: std.posix.fd_t) Io.File {
        return .{ .handle = fd, .flags = .{ .nonblocking = false } };
    }

    fn open(e: *Executor, w: u32) !PipedProc {
        const gpa = e.gpa;
        const io = e.io;
        var pp: PipedProc = .{ .p = try gpa.create(Proc), .stdin = undefined, .stdout = undefined, .stderr = undefined };
        errdefer gpa.destroy(pp.p);
        pp.stdin = try Io.Threaded.pipe2(.{ .CLOEXEC = true });
        pp.stdout = try Io.Threaded.pipe2(.{ .CLOEXEC = true });
        pp.stderr = try Io.Threaded.pipe2(.{ .CLOEXEC = true });
        const p = pp.p;
        p.child = undefined;
        p.mr.init(gpa, io, p.mr_buf.toStreams(), &.{ file(pp.stdout[0]), file(pp.stderr[0]) });
        p.stdin_writer = file(pp.stdin[1]).writerStreaming(io, &.{});
        p.client = .{ .in = p.mr.reader(0), .out = &p.stdin_writer.interface };
        e.procs[w] = p;
        return pp;
    }

    fn close(pp: PipedProc, e: *Executor, w: u32) void {
        e.procs[w] = null;
        pp.p.mr.deinit();
        for ([_][2]std.posix.fd_t{ pp.stdin, pp.stdout, pp.stderr }) |fds| {
            for (fds) |fd| file(fd).close(e.io);
        }
        e.gpa.destroy(pp.p);
    }

    /// The child's side of one test, as the test runner sends it:
    /// test_started, then test_results.
    fn sendResult(pp: PipedProc, io: Io, index: u32, flags: InMessage.TestResults.Flags) !void {
        var buffer: [64]u8 = undefined;
        var out = file(pp.stdout[1]).writerStreaming(io, &buffer);
        var server: std.zig.Server = .{ .in = undefined, .out = &out.interface };
        try server.serveStringMessage(.test_started, &.{});
        try server.serveTestResults(.{ .index = index, .flags = flags });
    }

    /// Waits until the launcher's side has read one test's two messages
    /// (and nothing else).
    fn readResult(pp: PipedProc) !void {
        const both = 2 * @sizeOf(InMessage.Header) + @sizeOf(InMessage.TestResults);
        while (pp.p.mr.reader(0).bufferedLen() < both) try pp.p.mr.fill(64, .none);
    }

    fn print(pp: PipedProc, io: Io, text: []const u8) !void {
        try file(pp.stderr[1]).writeStreamingAll(io, text);
    }
};

const logged_an_error: InMessage.TestResults.Flags = .{ .status = .pass, .fuzz = false, .log_err_count = 1, .leak_count = 0 };
const passed: InMessage.TestResults.Flags = .{ .status = .pass, .fuzz = false, .log_err_count = 0, .leak_count = 0 };

test "a failed test's output is what it printed before its result, though the launcher read the result first" {
    // The state the race in `readReady` leaves: the result already read, the
    // text the process printed before it still in the stderr pipe. (The
    // fixture test "the Crane test runner fails a test that leaves process
    // state behind" came back log_err with an empty output this way.)
    const gpa = testing.allocator;
    const io = testing.io;
    var e = try Executor.init(gpa, io, &.{"x"}, 10 * std.time.ns_per_s, 1);
    defer e.deinit();
    const pp = try PipedProc.open(&e, 0);
    defer pp.close(&e, 0);

    try pp.sendResult(io, 0, logged_an_error);
    try pp.readResult();
    try pp.print(io, "error: runtime.browsers: 0 -> 1\n");

    const res = try Executor.run(&e, 0, 0);
    defer gpa.free(res.output);
    try testing.expectEqual(sched.Status.log_err, res.status);
    try testing.expectEqualStrings("error: runtime.browsers: 0 -> 1\n", res.output);
}

test "what a passing test printed is not the next test's output" {
    // Two tests in one process: the first passes, its text still in the pipe
    // when its result is read; the second fails with text of its own.
    const gpa = testing.allocator;
    const io = testing.io;
    var e = try Executor.init(gpa, io, &.{"x"}, 10 * std.time.ns_per_s, 1);
    defer e.deinit();
    const pp = try PipedProc.open(&e, 0);
    defer pp.close(&e, 0);

    try pp.sendResult(io, 0, passed);
    try pp.readResult();
    try pp.print(io, "the first test's line\n");
    const first = try Executor.run(&e, 0, 0);
    try testing.expectEqual(sched.Status.pass, first.status);
    try testing.expectEqual(@as(usize, 0), first.output.len);

    try pp.print(io, "error: the second test's line\n");
    try pp.sendResult(io, 1, logged_an_error);
    const second = try Executor.run(&e, 0, 1);
    defer gpa.free(second.output);
    try testing.expectEqual(sched.Status.log_err, second.status);
    try testing.expectEqualStrings("error: the second test's line\n", second.output);
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
    // The fixture's first eight tests; "sees the fixed environment" and
    // verify mode's flake follow them and have tests of their own.
    try testing.expectEqual(names.len + 2, md.names.len);
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
    // Only "hangs" may time out: 2 s for it, 120 s for the others, which the
    // launcher's `slow` gives (slow_factor times the timeout). With 2 s for
    // all, under background QoS (taskpolicy -b, 4 runs at once) "fails" or
    // "leaks" took over 2 s to answer in 14 runs of 200 and was blamed as a
    // timeout (lane testfix2).
    var slow: [names.len]bool = undefined;
    for (&slow, names) |*s, name| s.* = !std.mem.eql(u8, name, "hangs");
    exec.slow = &slow;
    exec.slow_factor = 60;
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

test "the test environment: the launcher's own, with the time zone and locale fixed and the proxies cleared" {
    const gpa = testing.allocator;
    var base: std.process.Environ.Map = .init(gpa);
    defer base.deinit();
    try base.put("TZ", "UTC");
    try base.put("LANG", "C");
    try base.put("http_proxy", "http://proxy.invalid:3128");
    try base.put("HTTPS_PROXY", "http://proxy.invalid:3128");
    try base.put("PATH", "/usr/bin:/bin");
    var env = try testEnvironment(gpa, &base, .{});
    defer env.deinit();
    try testing.expectEqualStrings("America/Los_Angeles", env.get("TZ").?);
    try testing.expectEqualStrings("en_US.UTF-8", env.get("LANG").?);
    try testing.expectEqualStrings("en_US.UTF-8", env.get("LC_ALL").?);
    try testing.expect(env.get("http_proxy") == null);
    try testing.expect(env.get("HTTPS_PROXY") == null);
    // Everything else is the launcher's.
    try testing.expectEqualStrings("/usr/bin:/bin", env.get("PATH").?);
    // The launcher's own map is not changed.
    try testing.expectEqualStrings("UTC", base.get("TZ").?);
}

test "the test environment: libc scribbles what it frees, unless CRANE_POISON_FREES=0 turns all poisoning off" {
    const gpa = testing.allocator;
    var base: std.process.Environ.Map = .init(gpa);
    defer base.deinit();
    const pair = malloc_scribble orelse return error.SkipZigTest;
    var on = try testEnvironment(gpa, &base, .{});
    defer on.deinit();
    try testing.expectEqualStrings(pair[1], on.get(pair[0]).?);
    try testing.expect(on.get(poisoning.env_var) == null);

    // The one-run off switch: passed through for the child's test runner,
    // and libc's scribbling off with it - even if the launcher had it set.
    try base.put(poisoning.env_var, "0");
    try base.put(pair[0], pair[1]);
    var off = try testEnvironment(gpa, &base, .{});
    defer off.deinit();
    try testing.expect(off.get(pair[0]) == null);
    try testing.expectEqualStrings("0", off.get(poisoning.env_var).?);
}

test "the test environment under ThreadSanitizer: a race halts the child, with the suppressions; the launcher's own TSAN_OPTIONS come last and win" {
    const gpa = testing.allocator;
    var base: std.process.Environ.Map = .init(gpa);
    defer base.deinit();
    // Not instrumented: no TSAN_OPTIONS is added.
    var plain = try testEnvironment(gpa, &base, .{});
    defer plain.deinit();
    try testing.expect(plain.get("TSAN_OPTIONS") == null);
    try testing.expect(plain.get(many_browsers_variable) == null);

    var tsan = try testEnvironment(gpa, &base, .{ .sanitize_thread = .{ .suppressions = "/abs/tsan_suppressions.txt" } });
    defer tsan.deinit();
    try testing.expectEqualStrings("halt_on_error=1:second_deadlock_stack=1:suppressions=/abs/tsan_suppressions.txt", tsan.get("TSAN_OPTIONS").?);

    try base.put("TSAN_OPTIONS", "history_size=7");
    var by_hand = try testEnvironment(gpa, &base, .{ .sanitize_thread = .{} });
    defer by_hand.deinit();
    try testing.expectEqualStrings("halt_on_error=1:second_deadlock_stack=1:history_size=7", by_hand.get("TSAN_OPTIONS").?);
    try testing.expectEqualStrings("history_size=7", base.get("TSAN_OPTIONS").?);

    // The many-Browsers variant: the Crane test runner starts its busy Browser.
    var many = try testEnvironment(gpa, &base, .{ .many_browsers = true });
    defer many.deinit();
    try testing.expectEqualStrings("1", many.get(many_browsers_variable).?);
}

test "real processes: under ThreadSanitizer a data race halts the test child, and the launcher blames the test that raced" {
    // build.zig compiles tools/test_launcher/tsan_fixture_test.zig with
    // sanitize_thread and passes its path.
    const fixture = @import("launcher_fixture");
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ fixture.tsan_path, "--listen=-", "--seed=0x1" };
    const md = try queryMetadata(gpa, io, &argv);
    defer md.deinit(gpa);
    const names = [_][]const u8{ "passes before", "races", "passes after" };
    try testing.expectEqual(names.len, md.names.len);
    var all: [names.len]u32 = undefined;
    for (names, 0..) |want, i| {
        try testing.expect(std.mem.endsWith(u8, md.names[i], want));
        all[i] = @intCast(i);
    }

    var base: std.process.Environ.Map = .init(gpa);
    defer base.deinit();
    var env = try testEnvironment(gpa, &base, .{ .sanitize_thread = .{} });
    defer env.deinit();
    // One process for the three: the race kills it, the test after runs in
    // a new one.
    var plan = try @import("plan.zig").make(gpa, &all, .{ .seed = 1, .shuffle = false, .batch_size = 0 });
    defer plan.deinit(gpa);
    var exec = try Executor.init(gpa, io, &argv, 60 * std.time.ns_per_s, 1);
    defer exec.deinit();
    exec.environ_map = &env;
    var run = try sched.Run.init(gpa, io, &plan, md.names.len, exec.executor(), .{ .jobs = 1, .alone_runs = 1 });
    defer run.deinit();
    try run.execute();
    errdefer std.debug.print("{s}\n", .{run.records[1].output});
    try testing.expectEqual(sched.Status.pass, run.records[0].first);
    try testing.expectEqual(sched.Status.crash, run.records[1].first);
    try testing.expectEqual(sched.Verdict.fail, run.records[1].verdict);
    try testing.expect(std.mem.indexOf(u8, run.records[1].output, "WARNING: ThreadSanitizer: data race") != null);
    try testing.expectEqual(sched.Status.pass, run.records[2].first);
}

test "real processes: the many-Browsers variant runs a busy Browser beside each test, and only with it does a test that assumes it is alone fail" {
    // build.zig compiles tests/test_runner_fixture/many_browsers_fixture.zig
    // (it links V8) only with -Dmany-browsers.
    const fixture = @import("launcher_fixture");
    if (@hasDecl(fixture, "many_browsers_path")) try manyBrowsersFixture(fixture.many_browsers_path) else return error.SkipZigTest;
}

fn manyBrowsersFixture(path: []const u8) !void {
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ path, "--listen=-", "--seed=0x1" };
    const md = try queryMetadata(gpa, io, &argv);
    defer md.deinit(gpa);
    try testing.expectEqual(@as(usize, 2), md.names.len);
    try testing.expect(std.mem.endsWith(u8, md.names[0], "assumes it is the only Browser in its process"));
    try testing.expect(std.mem.endsWith(u8, md.names[1], "assumes nothing"));

    var base: std.process.Environ.Map = .init(gpa);
    defer base.deinit();
    for ([_]struct { many: bool, want: [2]sched.Status }{
        .{ .many = false, .want = .{ .pass, .pass } },
        .{ .many = true, .want = .{ .fail, .pass } },
    }) |case| {
        var env = try testEnvironment(gpa, &base, .{ .many_browsers = case.many });
        defer env.deinit();
        var all = [_]u32{ 0, 1 };
        var plan = try @import("plan.zig").make(gpa, &all, .{ .seed = 1, .shuffle = false, .batch_size = 1 });
        defer plan.deinit(gpa);
        var exec = try Executor.init(gpa, io, &argv, 120 * std.time.ns_per_s, 2);
        defer exec.deinit();
        exec.environ_map = &env;
        var run = try sched.Run.init(gpa, io, &plan, md.names.len, exec.executor(), .{ .jobs = 2, .alone_runs = 1 });
        defer run.deinit();
        try run.execute();
        for (case.want, 0..) |want, i| {
            errdefer std.debug.print("many Browsers {}: test {d}: {t}\n{s}\n", .{ case.many, i, run.records[i].first, run.records[i].output });
            try testing.expectEqual(want, run.records[i].first);
        }
        if (case.many) try testing.expect(std.mem.indexOf(u8, run.records[0].output, "AnotherBrowserIsAlive") != null);
    }
}

test "real processes: a test child sees the fixed environment whatever the launcher's was" {
    const fixture = @import("launcher_fixture");
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ fixture.path, "--listen=-", "--seed=0x1" };
    const md = try queryMetadata(gpa, io, &argv);
    defer md.deinit(gpa);
    const index: u32 = for (md.names, 0..) |n, i| {
        if (std.mem.endsWith(u8, n, "sees the fixed environment")) break @intCast(i);
    } else return error.FixtureTestMissing;

    // A launcher environment unlike the fixed one, as a shell might have it.
    var base: std.process.Environ.Map = .init(gpa);
    defer base.deinit();
    try base.put("TZ", "Asia/Tokyo");
    try base.put("LANG", "de_DE.UTF-8");
    try base.put("https_proxy", "http://proxy.invalid:3128");
    var fixed = try testEnvironment(gpa, &base, .{});
    defer fixed.deinit();

    // The fixture is sensitive: run with the launcher's environment as it
    // is, it fails; with the fixed one, it passes.
    for ([_]struct { env: *const std.process.Environ.Map, want: sched.Status }{
        .{ .env = &base, .want = .fail },
        .{ .env = &fixed, .want = .pass },
    }) |case| {
        var one = [_]u32{index};
        var plan = try @import("plan.zig").make(gpa, &one, .{ .seed = 1, .shuffle = false, .batch_size = 0 });
        defer plan.deinit(gpa);
        var exec = try Executor.init(gpa, io, &argv, 30 * std.time.ns_per_s, 1);
        defer exec.deinit();
        exec.environ_map = case.env;
        var run = try sched.Run.init(gpa, io, &plan, md.names.len, exec.executor(), .{ .jobs = 1, .alone_runs = 1 });
        defer run.deinit();
        try run.execute();
        errdefer std.debug.print("{s}\n", .{run.records[index].output});
        try testing.expectEqual(case.want, run.records[index].first);
    }
}

test "real processes: the Crane test runner fails a test that leaves process state behind, by the field's name" {
    // build.zig compiles tests/test_runner_fixture/state_fixture.zig with the
    // Crane test runner (tests/test_runner/), its state check failing, and
    // passes its path.
    const fixture = @import("launcher_fixture");
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ fixture.state_path, "--listen=-", "--seed=0x1" };
    const md = try queryMetadata(gpa, io, &argv);
    defer md.deinit(gpa);

    // Each test, with what its first run must be and what its output must
    // name: the field it left changed, its value before and after.
    const cases = [_]struct { name: []const u8, first: sched.Status, says: ?[]const u8 }{
        .{ .name = "leaves nothing", .first = .pass, .says = null },
        .{ .name = "leaves a Browser alive", .first = .log_err, .says = "runtime.browsers: 0 -> 1" },
        .{ .name = "makes a standalone runtime of its own and ends it", .first = .pass, .says = null },
        .{ .name = "makes a standalone runtime and leaves it", .first = .log_err, .says = "runtime.standalone_runtime: 0 -> 1" },
        .{ .name = "installs a hook for itself, as startHooksForTest does", .first = .pass, .says = null },
        .{ .name = "starts the process, installing a hook", .first = .pass, .says = null },
        .{ .name = "overrides a hook and gives it back", .first = .pass, .says = null },
        .{ .name = "leaves a hook overridden", .first = .log_err, .says = "process_start.outstanding_overrides: 0 -> 1" },
        .{ .name = "leaves the process starting", .first = .log_err, .says = "process_start.phase: not_started -> starting" },
        .{ .name = "ends the process", .first = .log_err, .says = "process_start.phase: not_started -> ended" },
        .{ .name = "leaves the active cleanup coordinator set", .first = .log_err, .says = "global src/runtime/cleanup_coordinator.zig active_coordinator: " },
    };
    try testing.expectEqual(cases.len, md.names.len);
    var all: [cases.len]u32 = undefined;
    for (cases, 0..) |c, i| {
        try testing.expect(std.mem.endsWith(u8, md.names[i], c.name));
        all[i] = @intCast(i);
    }

    // A process per test: each starts from a fresh process.
    var plan = try @import("plan.zig").make(gpa, &all, .{ .seed = 1, .shuffle = false, .batch_size = 1 });
    defer plan.deinit(gpa);
    var exec = try Executor.init(gpa, io, &argv, 60 * std.time.ns_per_s, 1);
    defer exec.deinit();
    var run = try sched.Run.init(gpa, io, &plan, md.names.len, exec.executor(), .{ .jobs = 1, .alone_runs = 1 });
    defer run.deinit();
    try run.execute();
    for (cases, 0..) |c, i| {
        const rec = run.records[i];
        errdefer std.debug.print("test {s}: first {t}\n{s}\n", .{ c.name, rec.first, rec.output });
        try testing.expectEqual(c.first, rec.first);
        if (c.says) |text| try testing.expect(std.mem.indexOf(u8, rec.output, text) != null);
    }
}

/// What a load through a pointer made of poison (0x5555555555555555, read
/// from a destroyed struct) prints. On x86-64 that address is not canonical
/// (bits 63-48 do not repeat bit 47), so the load raises a general
/// protection exception, #GP, which carries no fault address and Zig's
/// handler names as such; on arm64 it is an ordinary translation fault - a
/// segmentation fault at the address (lane linux1: the first x86-64 Linux
/// run printed "General protection exception" here).
const poisoned_pointer_fault = switch (builtin.cpu.arch) {
    .x86_64 => "General protection exception",
    else => "Segmentation fault",
};

test "real processes: a read after a free fails its test by name - it reads the poison or faults - and CRANE_POISON_FREES=0 lets it read the old bytes" {
    // build.zig compiles tests/test_runner_fixture/poison_fixture.zig with
    // the Crane test runner and passes its path (lane poison2). Without
    // poisoning a read after a free finds the old bytes, so the off run is
    // the blind spot this closes: every such test passes there.
    const fixture = @import("launcher_fixture");
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ fixture.poison_path, "--listen=-", "--seed=0x1" };
    const md = try queryMetadata(gpa, io, &argv);
    defer md.deinit(gpa);

    // Each test, with its first run poisoned and what its output must say.
    // The libc case needs the launcher's scribble (`malloc_scribble`): with
    // none on this system the block keeps its bytes and the test passes.
    const libc_poisoned: sched.Status = if (malloc_scribble != null) .fail else .pass;
    const cases = [_]struct { name: []const u8, poisoned: sched.Status, says: ?[]const u8 }{
        // SafeAllocator's 0x55 read back: expected 0x1122334455667788.
        .{ .name = "std.testing.allocator: reads a field through a pointer kept past its destroy", .poisoned = .fail, .says = "expected 1234605616436508552, found 6148914691236517205" },
        .{ .name = "std.testing.allocator: follows a pointer read from a destroyed struct", .poisoned = .crash, .says = poisoned_pointer_fault },
        // poisoning.byte, 0xdd, read back.
        .{ .name = "a test's own DebugAllocator: reads a field through a pointer kept past its destroy", .poisoned = .fail, .says = "expected 1234605616436508552, found 15987178197214944733" },
        .{ .name = "a test's own DebugAllocator: reads a slice's bytes after its free", .poisoned = .fail, .says = "expected 17, found 221" },
        // libc's scribble (malloc_scribble), 0x55, read back.
        .{ .name = "std.heap.c_allocator: reads a block's bytes after its free", .poisoned = libc_poisoned, .says = if (malloc_scribble != null) "expected 17, found 85" else null },
        .{ .name = "reads only live memory", .poisoned = .pass, .says = null },
    };
    try testing.expectEqual(cases.len, md.names.len);
    var all: [cases.len]u32 = undefined;
    for (cases, 0..) |c, i| {
        try testing.expect(std.mem.endsWith(u8, md.names[i], c.name));
        all[i] = @intCast(i);
    }

    var base: std.process.Environ.Map = .init(gpa);
    defer base.deinit();
    for ([_]bool{ true, false }) |poisoned| {
        if (!poisoned) try base.put(poisoning.env_var, "0");
        var env = try testEnvironment(gpa, &base, .{});
        defer env.deinit();
        // A process per test: each starts from a fresh process.
        var plan = try @import("plan.zig").make(gpa, &all, .{ .seed = 1, .shuffle = false, .batch_size = 1 });
        defer plan.deinit(gpa);
        var exec = try Executor.init(gpa, io, &argv, 60 * std.time.ns_per_s, 1);
        defer exec.deinit();
        exec.environ_map = &env;
        var run = try sched.Run.init(gpa, io, &plan, md.names.len, exec.executor(), .{ .jobs = 1, .alone_runs = 1 });
        defer run.deinit();
        try run.execute();
        for (cases, 0..) |c, i| {
            const rec = run.records[i];
            errdefer std.debug.print("poisoned {}: test {s}: first {t}\n{s}\n", .{ poisoned, c.name, rec.first, rec.output });
            try testing.expectEqual(if (poisoned) c.poisoned else .pass, rec.first);
            if (poisoned) if (c.says) |text| try testing.expect(std.mem.indexOf(u8, rec.output, text) != null);
        }
    }
}

test "real processes: in a joined executable each member's standalone runtime is judged by its own row" {
    // build.zig compiles tests/test_runner_fixture/joined_fixture.zig as
    // -Dtest-binaries=v8 joins suites: member "start." with tests-v8's
    // .process_start (its test start makes the standalone runtime once, for
    // the process), member "held." with the default .per_test (lane onebin3:
    // the joined executable judged tests-v8's tests by its own default row,
    // so 10 of them failed `runtime.standalone_runtime: 0 -> 1`).
    const fixture = @import("launcher_fixture");
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ fixture.joined_path, "--listen=-", "--seed=0x1" };
    const md = try queryMetadata(gpa, io, &argv);
    defer md.deinit(gpa);

    const cases = [_]struct { name: []const u8, first: sched.Status, says: ?[]const u8 }{
        .{ .name = "start.member.test.makes the standalone runtime once, as its suite's test start does", .first = .pass, .says = null },
        .{ .name = "held.member.test.leaves nothing", .first = .pass, .says = null },
        .{ .name = "held.member.test.makes a standalone runtime and leaves it", .first = .log_err, .says = "runtime.standalone_runtime: 0 -> 1" },
    };
    var index: [cases.len]u32 = undefined;
    for (cases, &index) |c, *i| {
        i.* = for (md.names, 0..) |n, k| {
            if (std.mem.eql(u8, n, c.name)) break @intCast(k);
        } else {
            std.debug.print("no test named {s}\n", .{c.name});
            return error.TestUnexpectedResult;
        };
    }

    // A process per test: each starts from a fresh process.
    var plan = try @import("plan.zig").make(gpa, &index, .{ .seed = 1, .shuffle = false, .batch_size = 1 });
    defer plan.deinit(gpa);
    var exec = try Executor.init(gpa, io, &argv, 60 * std.time.ns_per_s, 1);
    defer exec.deinit();
    var run = try sched.Run.init(gpa, io, &plan, md.names.len, exec.executor(), .{ .jobs = 1, .alone_runs = 1 });
    defer run.deinit();
    try run.execute();
    for (cases, index) |c, i| {
        const rec = run.records[i];
        errdefer std.debug.print("test {s}: first {t}\n{s}\n", .{ c.name, rec.first, rec.output });
        try testing.expectEqual(c.first, rec.first);
        if (c.says) |text| try testing.expect(std.mem.indexOf(u8, rec.output, text) != null);
    }
}

test "a test executable that is not there: its tests are LAUNCHER-ERROR, with the path, the errno and whether it is there now" {
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ "/nonexistent/crane-test-launcher/no-such-exe", "--listen=-", "--seed=0x1" };
    var all = [_]u32{ 0, 1, 2 };
    var plan = try @import("plan.zig").make(gpa, &all, .{ .seed = 1, .shuffle = false, .batch_size = 0 });
    defer plan.deinit(gpa);
    var exec = try Executor.init(gpa, io, &argv, 2 * std.time.ns_per_s, 1);
    defer exec.deinit();
    var run = try sched.Run.init(gpa, io, &plan, all.len, exec.executor(), .{ .jobs = 1, .alone_runs = 2 });
    defer run.deinit();
    try run.execute();
    for (run.records) |rec| {
        try testing.expectEqual(sched.Verdict.launcher_error, rec.verdict);
        try testing.expectEqualStrings(
            "launcher: could not start the test process: could not spawn /nonexistent/crane-test-launcher/no-such-exe: FileNotFound (ENOENT); it is not there now\n",
            rec.cause,
        );
    }
    // One failed start, and nothing re-run.
    try testing.expectEqual(@as(u32, 1), run.processes.load(.monotonic));
    try testing.expectEqual(@as(u32, 3), run.counts().launcher_error);
}

test "a slot directory removed under the launcher: LAUNCHER-ERROR, naming the slot file" {
    const fixture = @import("launcher_fixture");
    const gpa = testing.allocator;
    const io = testing.io;
    const argv = [_][]const u8{ fixture.path, "--listen=-", "--seed=0x1" };
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(gpa, ".zig-cache/tmp/{s}/slots", .{tmp.sub_path});
    defer gpa.free(path);
    var slots = try Slots.open(io, path, 1);
    defer slots.close();
    try tmp.dir.deleteTree(io, "slots");

    // Test 0 of the fixture: "passes".
    var one = [_]u32{0};
    var plan = try @import("plan.zig").make(gpa, &one, .{ .seed = 1, .shuffle = false, .batch_size = 0 });
    defer plan.deinit(gpa);
    var exec = try Executor.init(gpa, io, &argv, 2 * std.time.ns_per_s, 1);
    defer exec.deinit();
    exec.slots = &slots;
    var run = try sched.Run.init(gpa, io, &plan, 8, exec.executor(), .{ .jobs = 1, .alone_runs = 2 });
    defer run.deinit();
    try run.execute();
    const rec = run.records[0];
    try testing.expectEqual(sched.Verdict.launcher_error, rec.verdict);
    const want = try std.fmt.allocPrint(gpa, "launcher: could not start the test process: could not take a test-process slot, {s}/slot-0: FileNotFound (ENOENT)\n", .{path});
    defer gpa.free(want);
    try testing.expectEqualStrings(want, rec.cause);
}

test "an error prints with the errno it stands for, where it has one" {
    var buf: [64]u8 = undefined;
    try testing.expectEqualStrings("FileNotFound (ENOENT)", try std.fmt.bufPrint(&buf, "{f}", .{FmtError{ .err = error.FileNotFound }}));
    try testing.expectEqualStrings("Unexpected", try std.fmt.bufPrint(&buf, "{f}", .{FmtError{ .err = error.Unexpected }}));
}

test "a process that exits non-zero after exit is reported with its code or signal and what it printed while exiting" {
    var buf: [exit_report_tail + 256]u8 = undefined;
    const by_signal = exitFailureReport(&buf, .{ .signal = .SEGV }, "# Fatal error in v8::Isolate::Dispose\n");
    try std.testing.expect(std.mem.indexOf(u8, by_signal, "terminated with signal SEGV") != null);
    try std.testing.expect(std.mem.indexOf(u8, by_signal, "# Fatal error in v8::Isolate::Dispose") != null);
    const by_code = exitFailureReport(&buf, .{ .exited = 134 }, "");
    try std.testing.expect(std.mem.indexOf(u8, by_code, "exited with code 134") != null);
    try std.testing.expect(std.mem.indexOf(u8, by_code, "nothing") != null);
}

test "the report keeps the last bytes of what a process printed while exiting" {
    var long: [exit_report_tail * 2]u8 = undefined;
    @memset(long[0..exit_report_tail], 'a');
    @memset(long[exit_report_tail..], 'z');
    var kept_buf: [exit_report_tail]u8 = undefined;
    const kept = tail(&kept_buf, &long);
    try std.testing.expectEqual(@as(usize, exit_report_tail), kept.len);
    try std.testing.expect(std.mem.allEqual(u8, kept, 'z'));
    try std.testing.expectEqualStrings("short", tail(&kept_buf, "short"));
}
