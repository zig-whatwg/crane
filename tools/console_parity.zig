//! WPT parity through the browser console: run WPT test files through the
//! console binary (tools/repl.zig, `zig-out/bin/repl`) against a host's
//! `wpt serve`, the way a person would - `repl <url>`, let testharness.js
//! finish, read its results - and compare each file's passing subtests with
//! a WPT runner journal of the same files. What the WPT runner says passes
//! should pass in the console too; every difference is a console bug or a
//! known difference of the two hosts' setup (the runner's testing platform:
//! its media and image backends, TestUtils, testdriver's vendor actions).
//!
//!     zig build console-parity -j2
//!     ./zig-out/bin/console_parity --repl=zig-out/bin/repl --list=<sources.txt> \
//!         --journal=<journal.jsonl> --wpt-root=tests/wpt --out=<dir> [--jobs=4] [--timeout=70000]
//!
//! A source runs once per global it declares that the runner runs, times
//! each variant - the runner's own loop (tests/wpt_runner/main.zig), with its
//! own parser (tests/wpt_runner/test_parser.zig) and its URLs
//! (wpt_server.zig buildTestUrl, mirrored in `testUrl`) - and its counts are
//! the sum, as the journal's are. Each run is one console process: its input
//! is one line that waits for testharness's completion and logs the results
//! as JSON (`collector`), then `.exit`. The console is given WPT's CA bundle
//! (`--ca-bundle`), as the runner trusts it, so https tests verify as they do
//! there.
//!
//! Writes `<out>/parity.tsv` (a row per source: both sides' status and
//! counts), `<out>/summary.txt` (totals, and every source whose passing
//! count differs, with hints of the known host differences its source
//! shows), and `<out>/logs/` (the console's output for each differing run).
const std = @import("std");
const test_parser = @import("wpt_test_parser");

pub const usage =
    \\usage: console_parity --repl=<repl binary> --list=<sources> --journal=<journal.jsonl>
    \\                      --wpt-root=<tests/wpt> --out=<dir> [--jobs=<n>] [--timeout=<ms>]
    \\
;

const Options = struct {
    repl: []const u8 = "zig-out/bin/repl",
    list: []const u8 = "",
    journal: []const u8 = "",
    wpt_root: []const u8 = "tests/wpt",
    out: []const u8 = "",
    jobs: usize = 4,
    /// The console's --timeout: its load and evaluation ceilings. Above
    /// testharness's own long timeout (60 s), which reports a TIMEOUT first.
    timeout_ms: u64 = 70_000,
};

fn valueOf(arg: []const u8, name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, arg, name) or arg.len <= name.len or arg[name.len] != '=') return null;
    return arg[name.len + 1 ..];
}

fn parseOptions(args: []const []const u8) !Options {
    var options: Options = .{};
    for (args) |arg| {
        if (valueOf(arg, "--repl")) |v| options.repl = v else if (valueOf(arg, "--list")) |v| options.list = v else if (valueOf(arg, "--journal")) |v| options.journal = v else if (valueOf(arg, "--wpt-root")) |v| options.wpt_root = v else if (valueOf(arg, "--out")) |v| options.out = v else if (valueOf(arg, "--jobs")) |v| {
            options.jobs = try std.fmt.parseUnsigned(usize, v, 10);
        } else if (valueOf(arg, "--timeout")) |v| {
            options.timeout_ms = try std.fmt.parseUnsigned(u64, v, 10);
        } else return error.UnknownOption;
    }
    if (options.list.len == 0 or options.journal.len == 0 or options.out.len == 0 or options.jobs == 0) return error.MissingOption;
    return options;
}

// ============================================================================
// Test URLs: the runner's
// ============================================================================

const WPT_HOST = "web-platform.test";

/// wpt_server.zig `Listener.of`: `.h2.` in the filename is wpt serve's
/// HTTP/2 listener (9000), `.https.` its TLS one (8443), else plain (8000).
fn listenerOf(path: []const u8) enum { http, https, h2 } {
    const base = std.fs.path.basename(path);
    if (std.mem.indexOf(u8, base, ".h2.") != null) return .h2;
    if (std.mem.indexOf(u8, base, ".https.") != null) return .https;
    return .http;
}

/// wpt_server.zig `hasHttpsQueryFlag`: a variant's `wpt_flags=https`.
fn hasHttpsQueryFlag(variant: []const u8) bool {
    const before_fragment = variant[0 .. std.mem.indexOfScalar(u8, variant, '#') orelse variant.len];
    const query_start = std.mem.indexOfScalar(u8, before_fragment, '?') orelse return false;
    var fields = std.mem.splitScalar(u8, before_fragment[query_start + 1 ..], '&');
    while (fields.next()) |field| {
        const equals = std.mem.indexOfScalar(u8, field, '=') orelse continue;
        var key_buffer: ["wpt_flags".len]u8 = undefined;
        const key = (std.Uri.Component{ .percent_encoded = field[0..equals] }).toRaw(&key_buffer) catch continue;
        if (!std.mem.eql(u8, key, "wpt_flags")) continue;
        var value_buffer: ["https".len]u8 = undefined;
        const value = (std.Uri.Component{ .percent_encoded = field[equals + 1 ..] }).toRaw(&value_buffer) catch continue;
        if (std.mem.eql(u8, value, "https")) return true;
    }
    return false;
}

/// wpt_server.zig `WptServer.buildTestUrl`, on wpt serve's default ports.
/// OWNED by `allocator`.
pub fn testUrl(allocator: std.mem.Allocator, path: []const u8, context: test_parser.GlobalType, variant: []const u8) ![]u8 {
    var url_path = path;
    var suffix: []const u8 = "";
    if (std.mem.endsWith(u8, path, ".any.js")) {
        url_path = path[0 .. path.len - 7];
        suffix = switch (context) {
            .worker => ".any.worker.html",
            .sharedworker => ".any.sharedworker.html",
            .serviceworker => ".any.serviceworker.html",
            .worker_module => ".any.worker-module.html",
            .sharedworker_module => ".any.sharedworker-module.html",
            .serviceworker_module => ".any.serviceworker-module.html",
            else => ".any.html",
        };
    } else if (std.mem.endsWith(u8, path, ".window.js")) {
        url_path = path[0 .. path.len - 10];
        suffix = ".window.html";
    } else if (std.mem.endsWith(u8, path, ".worker.js")) {
        url_path = path[0 .. path.len - 10];
        suffix = ".worker.html";
    }
    var listener = listenerOf(path);
    switch (context) {
        .serviceworker, .serviceworker_module => if (listener != .h2) {
            listener = .https;
        },
        else => {},
    }
    if (listener == .http and hasHttpsQueryFlag(variant)) listener = .https;
    const scheme: []const u8 = if (listener == .http) "http" else "https";
    const port: u16 = switch (listener) {
        .http => 8000,
        .https => 8443,
        .h2 => 9000,
    };
    return std.fmt.allocPrint(allocator, "{s}://{s}:{d}/{s}{s}{s}", .{ scheme, WPT_HOST, port, url_path, suffix, variant });
}

test "testUrl builds the runner's URLs" {
    const a = std.testing.allocator;
    const cases = [_]struct { path: []const u8, context: test_parser.GlobalType, variant: []const u8, url: []const u8 }{
        .{ .path = "url/url-constructor.any.js", .context = .window, .variant = "", .url = "http://web-platform.test:8000/url/url-constructor.any.html" },
        .{ .path = "url/url-constructor.any.js", .context = .worker, .variant = "", .url = "http://web-platform.test:8000/url/url-constructor.any.worker.html" },
        .{ .path = "url/url-constructor.any.js", .context = .serviceworker, .variant = "", .url = "https://web-platform.test:8443/url/url-constructor.any.serviceworker.html" },
        .{ .path = "cookiestore/x.https.any.js", .context = .serviceworker, .variant = "?v", .url = "https://web-platform.test:8443/cookiestore/x.https.any.serviceworker.html?v" },
        .{ .path = "dom/nodes/Element-matches.html", .context = .window, .variant = "", .url = "http://web-platform.test:8000/dom/nodes/Element-matches.html" },
        .{ .path = "encoding/single-byte-decoder.html", .context = .window, .variant = "?windows-1252", .url = "http://web-platform.test:8000/encoding/single-byte-decoder.html?windows-1252" },
        .{ .path = "fetch/x.h2.any.js", .context = .window, .variant = "", .url = "https://web-platform.test:9000/fetch/x.h2.any.html" },
    };
    for (cases) |case| {
        const url = try testUrl(a, case.path, case.context, case.variant);
        defer a.free(url);
        try std.testing.expectEqualStrings(case.url, url);
    }
}

// ============================================================================
// One run: the console on one test URL
// ============================================================================

/// The console's input: wait for testharness to complete - its completion
/// callback, or, when it completed before the line ran, the "getmessages"
/// replay of its "complete" message (testharness.js WindowTestEnvironment) -
/// then log the results, one line, and end. The line carries each failing
/// subtest's name and message too, for the logs of a differing run.
///
/// The replay is asked for only once the harness has finished - its summary
/// is on the page (testharness.js Output, section#summary), or 20 s passed
/// for a page that shows none: the request is a `message` event at the test's
/// own window, and a test still running that listens for messages
/// (navigating-across-documents/004.html, choose-_parent-003.html) would take
/// it for one of its own. After the harness completes, a test's steps are
/// ignored.
const collector =
    \\await new Promise(resolve => { let done = false; const finish = (tests, status) => { if (done) return; done = true; console.log('@@WPT ' + JSON.stringify({status: status ? status.status : -1, message: status ? status.message : null, tests: Array.from(tests || [], t => t.status), failures: Array.from(tests || [], t => t.status ? String(t.name).slice(0, 200) + ': ' + String(t.message).slice(0, 300) : null).filter(Boolean)})); resolve(); }; if (typeof add_completion_callback !== 'function') { console.log('@@WPT {"status":-2,"tests":[]}'); return resolve(); } add_completion_callback(finish); addEventListener('message', e => { if (e.data && e.data.type === 'complete') finish(e.data.tests, e.data.status); }); const started = Date.now(); const ask = () => { if (done) return; if (document.querySelector('section#summary') || Date.now() - started > 20000) postMessage({type: 'getmessages'}, '*'); else setTimeout(ask, 250); }; ask(); }), undefined
    \\.exit
    \\
;

/// A run's outcome, as the journal counts it.
pub const Counts = struct {
    /// testharness's harness status (0 OK, 1 ERROR, 2 TIMEOUT, 3
    /// PRECONDITION_FAILED), or: -1 no status, -2 no harness on the page,
    /// -3 no results printed (the console ended first), -4 killed at the
    /// deadline.
    status: i32 = 0,
    passed: u32 = 0,
    failed: u32 = 0,
    timed_out: u32 = 0,
    notrun: u32 = 0,

    fn add(self: *Counts, other: Counts) void {
        // The worst status: anything not OK wins over OK.
        if (self.status == 0) self.status = other.status;
        self.passed += other.passed;
        self.failed += other.failed;
        self.timed_out += other.timed_out;
        self.notrun += other.notrun;
    }

    fn total(self: Counts) u32 {
        return self.passed + self.failed + self.timed_out + self.notrun;
    }
};

/// The counts in the console's output: its `@@WPT` line.
pub fn parseOutput(output: []const u8) Counts {
    const marker = "@@WPT ";
    const at = std.mem.indexOf(u8, output, marker) orelse return .{ .status = -3 };
    const start = at + marker.len;
    const end = std.mem.indexOfScalarPos(u8, output, start, '\n') orelse output.len;
    const Line = struct { status: i32, tests: []const i32 };
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = std.json.parseFromSliceLeaky(Line, arena.allocator(), output[start..end], .{ .ignore_unknown_fields = true }) catch return .{ .status = -3 };
    var counts: Counts = .{ .status = parsed.status };
    // testharness's test statuses: 0 PASS, 1 FAIL, 2 TIMEOUT, 3 NOTRUN,
    // 4 PRECONDITION_FAILED (counted as a failure, as the runner does).
    for (parsed.tests) |status| switch (status) {
        0 => counts.passed += 1,
        2 => counts.timed_out += 1,
        3 => counts.notrun += 1,
        else => counts.failed += 1,
    };
    return counts;
}

test "parseOutput reads the collector's line" {
    const counts = parseOutput("Crane browser console\n> [tab 1] @@WPT {\"status\":0,\"tests\":[0,0,1,3,2]}\nundefined\n");
    try std.testing.expectEqual(@as(i32, 0), counts.status);
    try std.testing.expectEqual(@as(u32, 2), counts.passed);
    try std.testing.expectEqual(@as(u32, 1), counts.failed);
    try std.testing.expectEqual(@as(u32, 1), counts.notrun);
    try std.testing.expectEqual(@as(u32, 1), counts.timed_out);
    try std.testing.expectEqual(@as(i32, -3), parseOutput("no results\n").status);
}

const Run = struct {
    source: usize,
    url: []u8,
    counts: Counts = .{},
    /// The console's output, kept for a run whose source differs.
    output: []u8 = &.{},
};

fn runConsole(allocator: std.mem.Allocator, io: std.Io, options: *const Options, run: *Run) void {
    const ca_bundle = std.fmt.allocPrint(allocator, "--ca-bundle={s}/tools/certs/cacert.pem", .{options.wpt_root}) catch return;
    defer allocator.free(ca_bundle);
    const timeout = std.fmt.allocPrint(allocator, "--timeout={d}", .{options.timeout_ms}) catch return;
    defer allocator.free(timeout);
    var fds: [2]std.posix.fd_t = undefined;
    if (std.c.pipe(&fds) != 0) return;
    // The input fits a pipe's buffer: written whole, then the end.
    _ = std.c.write(fds[1], collector.ptr, collector.len);
    _ = std.c.close(fds[1]);
    defer _ = std.c.close(fds[0]);
    var child = std.process.spawn(io, .{
        .argv = &.{ options.repl, run.url, ca_bundle, timeout },
        .stdin = .{ .file = .{ .handle = fds[0], .flags = .{ .nonblocking = false } } },
        .stdout = .pipe,
        .stderr = .pipe,
    }) catch {
        run.counts = .{ .status = -3 };
        return;
    };
    defer child.kill(io);
    var buffer: std.Io.File.MultiReader.Buffer(2) = undefined;
    var reader: std.Io.File.MultiReader = undefined;
    reader.init(allocator, io, buffer.toStreams(), &.{ child.stdout.?, child.stderr.? });
    defer reader.deinit();
    // The console's own ceilings, and a margin for its start and its end.
    const deadline: std.Io.Timeout = .{ .duration = .{ .raw = .fromMilliseconds(@intCast(2 * options.timeout_ms + 30_000)), .clock = .awake } };
    var killed = false;
    while (reader.fill(4096, deadline)) |_| {} else |err| switch (err) {
        error.EndOfStream => {},
        else => killed = true,
    }
    const stdout: []u8 = reader.toOwnedSlice(0) catch &.{};
    defer allocator.free(stdout);
    const stderr: []u8 = reader.toOwnedSlice(1) catch &.{};
    defer allocator.free(stderr);
    run.counts = if (killed) .{ .status = -4 } else parseOutput(stdout);
    run.output = std.mem.concat(allocator, u8, &.{ stdout, "\n--- stderr ---\n", stderr }) catch &.{};
}

// ============================================================================
// The journal
// ============================================================================

const JournalEntry = struct {
    status: []const u8,
    counts: Counts,
};

fn readJournal(arena: std.mem.Allocator, io: std.Io, path: []const u8) !std.StringHashMapUnmanaged(JournalEntry) {
    const text = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .unlimited);
    var map: std.StringHashMapUnmanaged(JournalEntry) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    const Record = struct { path: []const u8, status: []const u8 = "", passed: u32 = 0, failed: u32 = 0, timed_out: u32 = 0, notrun: u32 = 0 };
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const record = std.json.parseFromSliceLeaky(Record, arena, line, .{ .ignore_unknown_fields = true }) catch continue;
        // The latest record of a file wins, as the progress report takes it.
        try map.put(arena, record.path, .{ .status = record.status, .counts = .{
            .passed = record.passed,
            .failed = record.failed,
            .timed_out = record.timed_out,
            .notrun = record.notrun,
        } });
    }
    return map;
}

// ============================================================================
// Hints: the known differences of the two hosts' setup
// ============================================================================

/// What a source uses that the runner's host supplies and the console's does
/// not: testdriver's vendor actions (the runner's test_driver.zig), TestUtils
/// (the runner's namespace), the testing platform's media and image backends.
fn hintsOf(source: []const u8, out: *std.Io.Writer) !void {
    const hints = [_]struct { needle: []const u8, name: []const u8 }{
        .{ .needle = "testdriver", .name = "testdriver" },
        .{ .needle = "TestUtils", .name = "TestUtils" },
        .{ .needle = "<video", .name = "media" },
        .{ .needle = "<audio", .name = "media" },
        .{ .needle = "HTMLMediaElement", .name = "media" },
        .{ .needle = "<img", .name = "image" },
        .{ .needle = "\"img-tag\"", .name = "image" },
        .{ .needle = "createImageBitmap", .name = "image" },
        .{ .needle = "new Image(", .name = "image" },
    };
    var first = true;
    var said: [hints.len]bool = @splat(false);
    for (hints, 0..) |hint, i| {
        if (std.mem.indexOf(u8, source, hint.needle) == null) continue;
        var repeated = false;
        for (hints[0..i], 0..) |earlier, j| if (said[j] and std.mem.eql(u8, earlier.name, hint.name)) {
            repeated = true;
        };
        said[i] = true;
        if (repeated) continue;
        try out.print("{s}{s}", .{ if (first) "" else ",", hint.name });
        first = false;
    }
}

// ============================================================================
// main
// ============================================================================

const Work = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: *const Options,
    runs: []Run,
    next: std.atomic.Value(usize) = .init(0),
    done: std.atomic.Value(usize) = .init(0),

    fn worker(self: *Work) void {
        while (true) {
            const index = self.next.fetchAdd(1, .monotonic);
            if (index >= self.runs.len) return;
            runConsole(self.allocator, self.io, self.options, &self.runs[index]);
            const finished = self.done.fetchAdd(1, .monotonic) + 1;
            if (finished % 25 == 0) std.debug.print("console_parity: {d}/{d} runs\n", .{ finished, self.runs.len });
        }
    }
};

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;
    const arena = init.arena.allocator();
    const io = init.io;
    const argv = try init.minimal.args.toSlice(arena);
    const args = try arena.alloc([]const u8, argv.len -| 1);
    for (args, 0..) |*arg, i| arg.* = argv[i + 1];
    const options = parseOptions(args) catch {
        std.debug.print("{s}", .{usage});
        return 2;
    };
    const cwd = std.Io.Dir.cwd();

    // The sources, their runs.
    const list_text = try cwd.readFileAlloc(io, options.list, arena, .unlimited);
    var sources: std.ArrayListUnmanaged([]const u8) = .empty;
    var source_texts: std.ArrayListUnmanaged([]const u8) = .empty;
    var runs: std.ArrayListUnmanaged(Run) = .empty;
    var lines = std.mem.splitScalar(u8, list_text, '\n');
    while (lines.next()) |raw| {
        const path = std.mem.trim(u8, raw, " \t\r");
        if (path.len == 0 or path[0] == '#') continue;
        const file_path = try std.fs.path.join(arena, &.{ options.wpt_root, path });
        const content = cwd.readFileAlloc(io, file_path, arena, .unlimited) catch {
            std.debug.print("console_parity: {s}: not readable under {s}\n", .{ path, options.wpt_root });
            continue;
        };
        var parsed = test_parser.parseTestFile(arena, path, content) catch continue;
        defer parsed.deinit();
        const index = sources.items.len;
        try sources.append(arena, path);
        try source_texts.append(arena, content);
        for (parsed.metadata.globals.items) |global| {
            if (!global.isImplemented()) continue;
            for (parsed.metadata.variantsOrDefault()) |variant| {
                try runs.append(arena, .{ .source = index, .url = try testUrl(arena, path, global, variant) });
            }
        }
    }
    if (sources.items.len == 0 or runs.items.len == 0) {
        std.debug.print("console_parity: no runs (sources {d}, runs {d})\n", .{ sources.items.len, runs.items.len });
        return 2;
    }
    var journal = try readJournal(arena, io, options.journal);
    _ = &journal;
    std.debug.print("console_parity: {d} sources, {d} runs, {d} at once\n", .{ sources.items.len, runs.items.len, options.jobs });

    var work: Work = .{ .allocator = allocator, .io = io, .options = &options, .runs = runs.items };
    const threads = try arena.alloc(std.Thread, options.jobs);
    for (threads) |*thread| thread.* = try std.Thread.spawn(.{}, Work.worker, .{&work});
    for (threads) |thread| thread.join();
    defer for (runs.items) |run| allocator.free(run.output);

    // Per source: the console's sum, the journal's.
    const console_counts = try arena.alloc(Counts, sources.items.len);
    @memset(console_counts, .{});
    for (runs.items) |run| console_counts[run.source].add(run.counts);

    try cwd.createDirPath(io, options.out);
    const logs_dir = try std.fs.path.join(arena, &.{ options.out, "logs" });
    try cwd.createDirPath(io, logs_dir);
    var tsv: std.Io.Writer.Allocating = .init(arena);
    var summary: std.Io.Writer.Allocating = .init(arena);
    try tsv.writer.writeAll("source\trunner_status\trunner_passed\trunner_total\tconsole_status\tconsole_passed\tconsole_total\tdiff\thints\n");
    var same: usize = 0;
    var fewer: usize = 0;
    var more: usize = 0;
    var missing: usize = 0;
    var runner_passed: u64 = 0;
    var console_passed: u64 = 0;
    var differences: std.Io.Writer.Allocating = .init(arena);
    for (sources.items, 0..) |source, i| {
        const counts = console_counts[i];
        var hints: std.Io.Writer.Allocating = .init(arena);
        try hintsOf(source_texts.items[i], &hints.writer);
        const entry = journal.get(source) orelse {
            missing += 1;
            try tsv.writer.print("{s}\t-\t-\t-\t{d}\t{d}\t{d}\t-\t{s}\n", .{ source, counts.status, counts.passed, counts.total(), hints.written() });
            continue;
        };
        runner_passed += entry.counts.passed;
        console_passed += counts.passed;
        const diff = @as(i64, counts.passed) - @as(i64, entry.counts.passed);
        try tsv.writer.print("{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{s}\n", .{ source, entry.status, entry.counts.passed, entry.counts.total(), counts.status, counts.passed, counts.total(), diff, hints.written() });
        if (diff == 0) {
            same += 1;
            continue;
        }
        if (diff < 0) fewer += 1 else more += 1;
        try differences.writer.print("{d:>5}  {s}  (runner {s} {d}/{d}, console status {d} {d}/{d}){s}{s}\n", .{ diff, source, entry.status, entry.counts.passed, entry.counts.total(), counts.status, counts.passed, counts.total(), if (hints.written().len > 0) "  hints: " else "", hints.written() });
        // The console's output for each run of the source.
        for (runs.items, 0..) |run, r| {
            if (run.source != i) continue;
            const name = try std.fmt.allocPrint(arena, "{s}/{d}.txt", .{ logs_dir, r });
            var log: std.Io.Writer.Allocating = .init(arena);
            try log.writer.print("{s}\n{s}\n", .{ run.url, run.output });
            try cwd.writeFile(io, .{ .sub_path = name, .data = log.written() });
            try differences.writer.print("         log {s}\n", .{name});
        }
    }
    try summary.writer.print(
        \\console parity: {d} sources ({d} runs) through {s}
        \\journal: {s}
        \\same passing count: {d}; console fewer: {d}; console more: {d}; not in the journal: {d}
        \\passing subtests: runner {d}, console {d}
        \\
        \\differences (console - runner):
        \\{s}
    , .{ sources.items.len, runs.items.len, options.repl, options.journal, same, fewer, more, missing, runner_passed, console_passed, differences.written() });
    const tsv_path = try std.fs.path.join(arena, &.{ options.out, "parity.tsv" });
    try cwd.writeFile(io, .{ .sub_path = tsv_path, .data = tsv.written() });
    const summary_path = try std.fs.path.join(arena, &.{ options.out, "summary.txt" });
    try cwd.writeFile(io, .{ .sub_path = summary_path, .data = summary.written() });
    std.debug.print("{s}", .{summary.written()[0 .. std.mem.indexOf(u8, summary.written(), "differences") orelse summary.written().len]});
    return 0;
}
