//! The performance journal: one JSON line per (engine, version, workload,
//! run), the only thing the benchmark runner writes and the only thing the
//! report reads (docs/performance.md, "The journal").
//!
//! `Record` IS the format: its field names, their order and their types are
//! what a line holds, and std.json parses a line into it strictly - an
//! unknown field, a missing required one or a value of the wrong type is an
//! error, never a silent default. `validate` then checks what the types
//! cannot say (a status that needs a message, a timed row without samples).
//! The tests at the end pin a line byte for byte; changing the format means
//! changing `format_name` and those tests together.
//!
//! Units: times in milliseconds (f64, rounded to the microsecond when
//! written), memory in bytes (u64). Memory is the engine's whole process
//! set (docs/performance.md, "Memory"): phys_footprint summed over its
//! processes, the figure Activity Monitor calls Memory.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

/// The format and its version: the first field of every line.
pub const format_name = "crane-perf/1";

pub const EngineName = enum {
    crane,
    chrome,
    firefox,
    safari,
    lightpanda,

    pub fn label(e: EngineName) []const u8 {
        return switch (e) {
            .crane => "Crane",
            .chrome => "Chrome",
            .firefox => "Firefox",
            .safari => "Safari",
            .lightpanda => "Lightpanda",
        };
    }
};

pub const Status = enum {
    /// The workload ran to its end and its numbers are in the record.
    ok,
    /// The page reported an exception (the message says which).
    @"error",
    /// The page did not finish the workload in its time.
    timeout,
    /// The engine's process ended before the workload did.
    crash,
    /// The engine lacks something the workload needs (the message names it).
    unsupported,
};

/// What a record measures, and so which fields an `ok` record carries.
pub const Kind = enum {
    /// In-page timed samples of `ops` operations each (`wall_ms`), with the
    /// process set's CPU between the workload's marks and its memory.
    timed,
    /// A navigation chain: one cold document load per step (`wall_ms`: from
    /// the document's time origin to its load event) and the footprint after
    /// each (`series`).
    chain,
    /// One page left idle: the settled footprint.
    idle,
    /// From launching the engine to its first page's load mark (`wall_ms`,
    /// one sample): the launcher's and the engine's start-up, reported apart
    /// so that no other row includes it.
    startup,
    /// k engine instances side by side on the idle page: the footprint of
    /// all of them with 1, 2, ... k running (`series`).
    instances,
    /// A Crane-only gc_bench row (no browser equivalent): one process run,
    /// its wall time, instructions retired and peak footprint.
    gc_bench,
};

pub const Host = struct {
    /// The host's short name (`hostname -s`).
    name: []const u8,
    /// "macOS 26.1 (25B78)".
    os: []const u8,
    arch: []const u8,
    /// "Apple M4 Pro" (machdep.cpu.brand_string).
    cpu: []const u8,
    cores: u32,
    memory_bytes: u64,
};

pub const Engine = struct {
    name: EngineName,
    /// The engine's own version: Chrome's "157.0.8103.38"; Crane's commit.
    version: []const u8,
    /// How the binary was built: Crane's modes and allocator, a browser's
    /// release channel ("Chrome for Testing stable").
    build: []const u8,
    /// Crane: the commit the binary was built from.
    commit: ?[]const u8 = null,
    /// Crane: the optimize modes (root, Crane modules, C libraries, C
    /// sanitizer).
    optimize: ?[]const u8 = null,
    /// Crane: the V8 it links ("13.1.203 static").
    v8: ?[]const u8 = null,
    /// The executable launched.
    binary: []const u8,
    binary_sha256: []const u8,
    /// Every argument it was launched with but the page's URL.
    flags: []const []const u8,
};

pub const Memory = struct {
    /// phys_footprint summed over the engine's processes at the workload's
    /// first mark, at its last, and the most any 50 ms sample between them
    /// saw (a whole-run row: launch to end).
    footprint_start: u64,
    footprint_end: u64,
    footprint_peak: u64,
    /// Resident size summed at the last mark (counts shared pages once per
    /// process: for reference only).
    resident_end: u64,
    /// How many processes the set had at the last mark.
    processes: u32,
};

pub const Record = struct {
    format: []const u8,
    /// The perf round (0 is the baseline before any perf change).
    round: u32,
    /// When the engine was launched, UTC, RFC 3339 ("2026-11-05T18:00:00Z").
    time: []const u8,
    host: Host,
    engine: Engine,
    /// The page, relative to tests/perf/.
    page: []const u8,
    /// "dom.getter-loop": a group, a dot, a name; lowercase.
    workload: []const u8,
    kind: Kind,
    /// Which launch of this engine on this page (0, 1, ...).
    run: u32,
    status: Status,
    message: ?[]const u8 = null,
    /// Operations per timed sample.
    ops: u64 = 0,
    /// Wall time of each sample (timed), step (chain) or run (startup,
    /// gc_bench), in milliseconds.
    wall_ms: []const f64 = &.{},
    /// CPU (user + system) of the process set between the workload's marks.
    cpu_ms: ?f64 = null,
    /// Instructions retired by the process set between the marks, where the
    /// host counts them.
    instructions: ?u64 = null,
    memory: ?Memory = null,
    /// chain: the footprint after each step; instances: with 1..k running.
    series: []const u64 = &.{},
    /// Figures only Crane reports (a gc_bench row's retained bytes per
    /// cycle, engine heap, live handles), by name.
    counters: []const Counter = &.{},
    /// From launch to the page's load mark.
    launch_ms: ?f64 = null,
};

pub const Counter = struct {
    name: []const u8,
    value: f64,
};

pub const ValidationError = error{
    WrongFormat,
    BadTime,
    BadWorkloadName,
    BadPage,
    MissingVersion,
    BadSha256,
    MissingBuildIdentity,
    MissingMessage,
    MissingSamples,
    MissingOps,
    MissingCpu,
    MissingMemory,
    BadSeries,
    NegativeOrNonFinite,
    PeakBelowSample,
};

/// What the types alone cannot say about a record.
pub fn validate(r: Record) ValidationError!void {
    if (!std.mem.eql(u8, r.format, format_name)) return error.WrongFormat;
    if (!isTime(r.time)) return error.BadTime;
    if (!isWorkloadName(r.workload)) return error.BadWorkloadName;
    if (r.page.len == 0 or r.page[0] == '/' or std.mem.indexOf(u8, r.page, "..") != null) return error.BadPage;
    if (r.engine.version.len == 0 or r.engine.build.len == 0) return error.MissingVersion;
    if (!isSha256(r.engine.binary_sha256)) return error.BadSha256;
    // Crane's build identity: what the comparison rule requires (the
    // release build, never the correctness runner).
    if (r.engine.name == .crane) {
        if (r.engine.commit == null or r.engine.optimize == null or r.engine.v8 == null) return error.MissingBuildIdentity;
    }
    for (r.wall_ms) |v| try nonNegative(v);
    if (r.cpu_ms) |v| try nonNegative(v);
    if (r.launch_ms) |v| try nonNegative(v);
    if (r.memory) |m| {
        if (m.footprint_peak < m.footprint_end or m.footprint_peak < m.footprint_start) return error.PeakBelowSample;
    }
    if (r.status != .ok) {
        if (r.message == null or r.message.?.len == 0) return error.MissingMessage;
        return;
    }
    switch (r.kind) {
        .timed => {
            if (r.wall_ms.len == 0) return error.MissingSamples;
            if (r.ops == 0) return error.MissingOps;
            if (r.cpu_ms == null) return error.MissingCpu;
            if (r.memory == null) return error.MissingMemory;
        },
        .chain => {
            if (r.wall_ms.len == 0) return error.MissingSamples;
            if (r.series.len != r.wall_ms.len) return error.BadSeries;
            if (r.memory == null) return error.MissingMemory;
        },
        .idle => if (r.memory == null) return error.MissingMemory,
        .startup => if (r.wall_ms.len != 1) return error.MissingSamples,
        .instances => if (r.series.len < 2) return error.BadSeries,
        .gc_bench => {
            if (r.wall_ms.len != 1) return error.MissingSamples;
            if (r.memory == null) return error.MissingMemory;
        },
    }
}

fn nonNegative(v: f64) ValidationError!void {
    if (!std.math.isFinite(v) or v < 0) return error.NegativeOrNonFinite;
}

/// "2026-11-05T18:00:00Z", optionally with a fraction of a second.
pub fn isTime(s: []const u8) bool {
    if (s.len < 20 or s[s.len - 1] != 'Z') return false;
    const shape = "dddd-dd-ddTdd:dd:dd";
    for (shape, 0..) |c, i| {
        if (c == 'd') {
            if (!std.ascii.isDigit(s[i])) return false;
        } else if (s[i] != c) return false;
    }
    const rest = s[shape.len .. s.len - 1];
    if (rest.len == 0) return true;
    if (rest[0] != '.' or rest.len < 2) return false;
    for (rest[1..]) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

/// A group and a name, dot-separated, of [a-z0-9-] ("dom.getter-loop",
/// "load.news").
pub fn isWorkloadName(s: []const u8) bool {
    const dot = std.mem.indexOfScalar(u8, s, '.') orelse return false;
    if (dot == 0 or dot == s.len - 1) return false;
    for (s, 0..) |c, i| {
        const ok = (c >= 'a' and c <= 'z') or std.ascii.isDigit(c) or c == '-' or (c == '.' and i > 0 and s[i - 1] != '.');
        if (!ok) return false;
    }
    return true;
}

pub fn isSha256(s: []const u8) bool {
    if (s.len != 64) return false;
    for (s) |c| if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return false;
    return true;
}

pub const ParseError = std.json.ParseError(std.json.Scanner) || ValidationError;

/// One line, strictly: unknown fields and missing required ones fail.
/// Strings point into `line` or `arena`.
pub fn parseLine(arena: Allocator, line: []const u8) ParseError!Record {
    const r = try std.json.parseFromSliceLeaky(Record, arena, line, .{});
    try validate(r);
    return r;
}

/// Where a journal failed to read: its 1-based line and why.
pub const Failure = struct {
    line: usize = 0,
    err: anyerror = error.None,
};

/// Every record of a journal (blank lines skipped). On a bad line, `failure`
/// says which and why, and the error is returned.
pub fn parseJournal(arena: Allocator, bytes: []const u8, failure: *Failure) ![]Record {
    var out: std.ArrayList(Record) = .empty;
    var it = std.mem.splitScalar(u8, bytes, '\n');
    var n: usize = 0;
    while (it.next()) |raw| {
        n += 1;
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;
        const r = parseLine(arena, line) catch |err| {
            failure.* = .{ .line = n, .err = err };
            return err;
        };
        try out.append(arena, r);
    }
    return out.items;
}

/// `r` as one line, newline included. Times are rounded to the microsecond
/// first, so a line carries no float noise.
pub fn writeLine(w: *Io.Writer, r: Record) Io.Writer.Error!void {
    var buf: [max_samples]f64 = undefined;
    var copy = r;
    if (r.wall_ms.len <= max_samples) {
        for (r.wall_ms, 0..) |v, i| buf[i] = roundUs(v);
        copy.wall_ms = buf[0..r.wall_ms.len];
    }
    if (r.cpu_ms) |v| copy.cpu_ms = roundUs(v);
    if (r.launch_ms) |v| copy.launch_ms = roundUs(v);
    try std.json.Stringify.value(copy, .{ .emit_null_optional_fields = false }, w);
    try w.writeByte('\n');
}

/// The most samples one record carries rounded (more are written as they are).
pub const max_samples = 256;

pub fn roundUs(ms: f64) f64 {
    return @round(ms * 1000.0) / 1000.0;
}

// ============================================================================
// Tests: they pin the format
// ============================================================================

const testing = std.testing;

const sample_host: Host = .{ .name = "chat", .os = "macOS 26.1 (25B78)", .arch = "aarch64", .cpu = "Apple M4 Pro", .cores = 14, .memory_bytes = 68719476736 };

const sample_crane: Engine = .{
    .name = .crane,
    .version = "e7101e588f1",
    .build = "release: ReleaseSafe everywhere, C .trap, libc malloc",
    .commit = "e7101e588f1",
    .optimize = "root ReleaseSafe, Crane modules ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap",
    .v8 = "13.1.203 static",
    .binary = "zig-out/bin/repl",
    .binary_sha256 = "6472fd2f6472fd2f6472fd2f6472fd2f6472fd2f6472fd2f6472fd2f6472fd2f",
    .flags = &.{"--proxy=direct"},
};

fn sampleTimed() Record {
    return .{
        .format = format_name,
        .round = 0,
        .time = "2026-11-05T18:00:00Z",
        .host = sample_host,
        .engine = sample_crane,
        .page = "workloads/attributes.html",
        .workload = "dom.getter-loop",
        .kind = .timed,
        .run = 2,
        .status = .ok,
        .ops = 100000,
        .wall_ms = &.{ 12.5, 12.25 },
        .cpu_ms = 25.0,
        .memory = .{ .footprint_start = 1000, .footprint_end = 1200, .footprint_peak = 1300, .resident_end = 5000, .processes = 1 },
        .launch_ms = 310.5,
    };
}

/// The line `sampleTimed` writes: the format, byte for byte.
const golden_timed =
    \\{"format":"crane-perf/1","round":0,"time":"2026-11-05T18:00:00Z","host":{"name":"chat","os":"macOS 26.1 (25B78)","arch":"aarch64","cpu":"Apple M4 Pro","cores":14,"memory_bytes":68719476736},"engine":{"name":"crane","version":"e7101e588f1","build":"release: ReleaseSafe everywhere, C .trap, libc malloc","commit":"e7101e588f1","optimize":"root ReleaseSafe, Crane modules ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap","v8":"13.1.203 static","binary":"zig-out/bin/repl","binary_sha256":"6472fd2f6472fd2f6472fd2f6472fd2f6472fd2f6472fd2f6472fd2f6472fd2f","flags":["--proxy=direct"]},"page":"workloads/attributes.html","workload":"dom.getter-loop","kind":"timed","run":2,"status":"ok","ops":100000,"wall_ms":[12.5,12.25],"cpu_ms":25,"memory":{"footprint_start":1000,"footprint_end":1200,"footprint_peak":1300,"resident_end":5000,"processes":1},"series":[],"counters":[],"launch_ms":310.5}
    \\
;

test "a timed record is written as exactly the pinned line" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try writeLine(&out.writer, sampleTimed());
    try testing.expectEqualStrings(golden_timed, out.written());
}

test "the pinned line reads back into the same record" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const r = try parseLine(arena.allocator(), std.mem.trimEnd(u8, golden_timed, "\n"));
    try testing.expectEqual(EngineName.crane, r.engine.name);
    try testing.expectEqualStrings("dom.getter-loop", r.workload);
    try testing.expectEqual(Kind.timed, r.kind);
    try testing.expectEqual(@as(u64, 100000), r.ops);
    try testing.expectEqualSlices(f64, &.{ 12.5, 12.25 }, r.wall_ms);
    try testing.expectEqual(@as(?f64, 25), r.cpu_ms);
    try testing.expectEqual(@as(u64, 1300), r.memory.?.footprint_peak);
    try testing.expectEqualStrings("13.1.203 static", r.engine.v8.?);
    try testing.expectEqual(@as(?[]const u8, null), r.message);
}

test "an unknown field, a missing field or a wrong type is an error, not a default" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const line = std.mem.trimEnd(u8, golden_timed, "\n");
    // An unknown field.
    const extra = try std.mem.concat(a, u8, &.{ line[0 .. line.len - 1], ",\"surprise\":1}" });
    try testing.expectError(error.UnknownField, parseLine(a, extra));
    // A required field missing: the round.
    const missing = try std.mem.replaceOwned(u8, a, line, "\"round\":0,", "");
    try testing.expectError(error.MissingField, parseLine(a, missing));
    // A status the format does not have.
    const bad_status = try std.mem.replaceOwned(u8, a, line, "\"status\":\"ok\"", "\"status\":\"fine\"");
    try testing.expectError(error.InvalidEnumTag, parseLine(a, bad_status));
    // An engine the format does not have.
    const bad_engine = try std.mem.replaceOwned(u8, a, line, "\"name\":\"crane\"", "\"name\":\"netscape\"");
    try testing.expectError(error.InvalidEnumTag, parseLine(a, bad_engine));
}

test "validation: what the types cannot say" {
    var r = sampleTimed();
    try validate(r);

    r.format = "crane-perf/2";
    try testing.expectError(error.WrongFormat, validate(r));
    r = sampleTimed();
    r.time = "2026-11-05 18:00:00";
    try testing.expectError(error.BadTime, validate(r));
    r = sampleTimed();
    r.workload = "GetterLoop";
    try testing.expectError(error.BadWorkloadName, validate(r));
    r = sampleTimed();
    r.page = "../etc/passwd";
    try testing.expectError(error.BadPage, validate(r));
    r = sampleTimed();
    r.engine.binary_sha256 = "abc";
    try testing.expectError(error.BadSha256, validate(r));
    // Crane rows name their build: the comparison rule is the release build.
    r = sampleTimed();
    r.engine.v8 = null;
    try testing.expectError(error.MissingBuildIdentity, validate(r));
    // A browser row needs no Crane build identity.
    r = sampleTimed();
    r.engine = .{ .name = .chrome, .version = "157.0.8103.38", .build = "Chrome for Testing stable", .binary = "chrome", .binary_sha256 = "abababababababababababababababababababababababababababababababab", .flags = &.{"--headless=new"} };
    try validate(r);
    // A failed row says why, and needs no numbers.
    r = sampleTimed();
    r.status = .timeout;
    try testing.expectError(error.MissingMessage, validate(r));
    r.message = "no end mark in 300 s";
    r.wall_ms = &.{};
    r.memory = null;
    try validate(r);
    // An ok timed row needs samples, ops, CPU and memory.
    r = sampleTimed();
    r.wall_ms = &.{};
    try testing.expectError(error.MissingSamples, validate(r));
    r = sampleTimed();
    r.ops = 0;
    try testing.expectError(error.MissingOps, validate(r));
    r = sampleTimed();
    r.cpu_ms = null;
    try testing.expectError(error.MissingCpu, validate(r));
    r = sampleTimed();
    r.memory = null;
    try testing.expectError(error.MissingMemory, validate(r));
    r = sampleTimed();
    r.wall_ms = &.{ 1.0, -2.0 };
    try testing.expectError(error.NegativeOrNonFinite, validate(r));
    r = sampleTimed();
    r.memory.?.footprint_peak = 10;
    try testing.expectError(error.PeakBelowSample, validate(r));
}

test "validation: each kind's own fields" {
    var r = sampleTimed();
    r.kind = .chain;
    r.workload = "load.news";
    r.wall_ms = &.{ 40.0, 38.0 };
    r.series = &.{ 1000, 1100 };
    try validate(r);
    r.series = &.{1000};
    try testing.expectError(error.BadSeries, validate(r));

    r = sampleTimed();
    r.kind = .startup;
    r.wall_ms = &.{300.0};
    try validate(r);
    r.wall_ms = &.{ 300.0, 1.0 };
    try testing.expectError(error.MissingSamples, validate(r));

    r = sampleTimed();
    r.kind = .instances;
    r.series = &.{ 1000, 2000, 3000 };
    try validate(r);
    r.series = &.{1000};
    try testing.expectError(error.BadSeries, validate(r));

    r = sampleTimed();
    r.kind = .idle;
    r.wall_ms = &.{};
    try validate(r);
    r.memory = null;
    try testing.expectError(error.MissingMemory, validate(r));
}

test "a journal reads line by line and names the line that fails" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const line = std.mem.trimEnd(u8, golden_timed, "\n");
    const two = try std.mem.concat(a, u8, &.{ line, "\n\n", line, "\n" });
    var failure: Failure = .{};
    const records = try parseJournal(a, two, &failure);
    try testing.expectEqual(@as(usize, 2), records.len);

    const bad = try std.mem.concat(a, u8, &.{ line, "\n", "{\"format\":1}\n" });
    try testing.expectError(error.UnexpectedToken, parseJournal(a, bad, &failure));
    try testing.expectEqual(@as(usize, 2), failure.line);
}

test "times are written rounded to the microsecond" {
    var r = sampleTimed();
    r.wall_ms = &.{12.3456789};
    r.cpu_ms = 1.0000004;
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try writeLine(&out.writer, r);
    try testing.expect(std.mem.indexOf(u8, out.written(), "\"wall_ms\":[12.346]") != null);
    try testing.expect(std.mem.indexOf(u8, out.written(), "\"cpu_ms\":1,") != null);
}

test "names: workloads and times" {
    try testing.expect(isWorkloadName("dom.getter-loop"));
    try testing.expect(isWorkloadName("gc-bench.stream-reader"));
    try testing.expect(!isWorkloadName("dom"));
    try testing.expect(!isWorkloadName(".x"));
    try testing.expect(!isWorkloadName("dom..x"));
    try testing.expect(!isWorkloadName("Dom.x"));
    try testing.expect(isTime("2026-11-05T18:00:00.123Z"));
    try testing.expect(!isTime("2026-11-05T18:00:00.Z"));
    try testing.expect(!isTime("2026-11-05T18:00:00+00:00"));
}
