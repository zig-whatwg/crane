//! Package a Crane WPT sweep for wpt.fyi, and check a package's shape.
//!
//!     zig build wpt-upload-package -- build --input=<sweep dir> --manifest=<MANIFEST.json> \
//!         --out=<dir> [--crane-commit=<sha>] [--max-chunk-mb=64]
//!     zig build wpt-upload-package -- check <file.json.gz>...
//!
//! `build` gathers everything a supervised sweep leaves under its directory -
//! every `wptreport*.json` a child finished, every `*.wptreport.jsonl` result
//! stream, every journal - and writes gzipped wptreport chunks that wpt.fyi's
//! `/api/results/upload` accepts as repeated `result_file`s, plus `summary.txt`.
//! `check` re-reads such chunks and applies the checks wpt.fyi's results
//! processor applies (results-processor/wptreport.py in
//! github.com/web-platform-tests/wpt.fyi), so a package can be dry-run before
//! anyone uploads it. Uploading is not this tool's job.
//!
//! What the package holds, and why:
//!
//! * A child's report is written only when the child finishes. A child that
//!   crashed or was killed by the stall watchdog left none, so its finished
//!   files come from its result stream (one JSON line per test URL, written
//!   as each file finishes). A truncated or unreadable stream line is dropped
//!   and counted, never guessed at.
//! * The file a crashed child was on has no results at all; its journal
//!   record says CRASH (or TIMEOUT, for a stall kill). Each of its manifest
//!   URLs in a global the runner implements gets what wptrunner itself
//!   reports then: status CRASH, or TIMEOUT with wptrunner's external-timeout
//!   message, and no subtests (wptrunner's executors/base.py returns
//!   `test.make_result("CRASH", None), []` for a browser crash, and
//!   testrunner.py maps its forced-kill EXTERNAL-TIMEOUT to TIMEOUT).
//! * URLs in globals the runner does not implement (sharedworker,
//!   serviceworker, shadowrealm) get nothing: wpt.fyi shows them missing, and
//!   the summary counts them rather than inventing results.
//! * Crane's own tests (`/crane/`) are not WPT and are dropped.
//! * `run_info.browser_version` must name the Crane commit. The runner adds
//!   `+<sha>` only in a git checkout; chat's mirrors have none, so
//!   `--crane-commit` supplies it, and a package without one is refused.

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Statuses and URLs
// ============================================================================

/// Test-level statuses a testharness wptreport carries (wptrunner's
/// TestharnessResult.statuses, less the internal ones testrunner.py maps
/// away: INTERNAL-ERROR -> ERROR, EXTERNAL-TIMEOUT -> TIMEOUT).
pub const test_statuses = [_][]const u8{ "OK", "ERROR", "TIMEOUT", "CRASH", "PRECONDITION_FAILED", "SKIP" };

/// Subtest statuses (wptrunner's TestharnessSubtestResult.statuses).
pub const subtest_statuses = [_][]const u8{ "PASS", "FAIL", "TIMEOUT", "NOTRUN", "PRECONDITION_FAILED" };

fn isOneOf(s: []const u8, set: []const []const u8) bool {
    for (set) |x| if (std.mem.eql(u8, s, x)) return true;
    return false;
}

/// wptrunner's message for a test it had to kill (testrunner.py `_timeout`).
pub const external_timeout_message = "TestRunner hit external timeout (this may indicate a hang)";

/// Which kind of global a manifest URL runs in, as far as whether Crane's
/// runner can run it. Keep in step with `GlobalType.isImplemented` in
/// tests/wpt_runner/test_parser.zig.
pub const UrlGlobal = enum {
    runs,
    sharedworker,
    serviceworker,
    shadowrealm,

    pub fn of(url: []const u8) UrlGlobal {
        const path = url[0 .. std.mem.indexOfScalar(u8, url, '?') orelse url.len];
        if (std.mem.indexOf(u8, path, ".any.shadowrealm") != null) return .shadowrealm;
        if (std.mem.endsWith(u8, path, ".any.sharedworker.html")) return .sharedworker;
        if (std.mem.endsWith(u8, path, ".any.serviceworker.html") or
            std.mem.endsWith(u8, path, ".any.serviceworker-module.html")) return .serviceworker;
        // .any.html, .any.worker.html, .any.worker-module.html,
        // .any.sharedworker-module.html, .window.html, .worker.html, a plain
        // document: all run.
        return .runs;
    }
};

fn isCraneTest(test_id: []const u8) bool {
    return std.mem.startsWith(u8, test_id, "/crane/");
}

/// `bytes` with every invalid UTF-8 sequence replaced by U+FFFD. wpt.fyi
/// decodes reports as UTF-8 and rejects one that is not. Null when `bytes`
/// is already valid (nothing allocated).
pub fn repairUtf8(allocator: Allocator, bytes: []const u8) !?[]u8 {
    if (std.unicode.utf8ValidateSlice(bytes)) return null;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < bytes.len) {
        const len = std.unicode.utf8ByteSequenceLength(bytes[i]) catch {
            try out.appendSlice(allocator, "\u{FFFD}");
            i += 1;
            continue;
        };
        if (i + len <= bytes.len) {
            if (std.unicode.utf8Decode(bytes[i .. i + len])) |_| {
                try out.appendSlice(allocator, bytes[i .. i + len]);
                i += len;
                continue;
            } else |_| {}
        }
        try out.appendSlice(allocator, "\u{FFFD}");
        i += 1;
    }
    return try out.toOwnedSlice(allocator);
}

pub fn isFullSha(s: []const u8) bool {
    if (s.len != 40) return false;
    for (s) |c| if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return false;
    return true;
}

/// The browser_version to upload: the report's, with the Crane commit named.
/// A report version without `+<sha>` takes `crane_commit`'s first 9
/// characters (the runner's own short form); one that has it must agree with
/// `crane_commit` when both are given.
pub fn resolveBrowserVersion(allocator: Allocator, report_version: []const u8, crane_commit: ?[]const u8) ![]u8 {
    if (std.mem.indexOfScalar(u8, report_version, '+')) |plus| {
        const sha = report_version[plus + 1 ..];
        if (crane_commit) |c| {
            const n = @min(sha.len, c.len);
            if (n == 0 or !std.mem.eql(u8, sha[0..n], c[0..n])) return error.CraneCommitMismatch;
        }
        return allocator.dupe(u8, report_version);
    }
    const c = crane_commit orelse return error.BrowserVersionHasNoCommit;
    if (c.len < 7) return error.CraneCommitTooShort;
    return std.fmt.allocPrint(allocator, "{s}+{s}", .{ report_version, c[0..@min(c.len, 9)] });
}

// ============================================================================
// Validation - the shape wpt.fyi's results processor requires
// ============================================================================

pub const ResultError = error{
    ResultNotAnObject,
    TestIdMissing,
    TestIdNotAbsolute,
    StatusMissing,
    UnknownTestStatus,
    SubtestsMissing,
    SubtestNotAnObject,
    SubtestNameMissing,
    UnknownSubtestStatus,
};

pub const ResultInfo = struct {
    test_id: []const u8,
    status: []const u8,
    subtests: usize,
    passed: usize,
};

/// Check one result object: `test` a string starting with '/', `status` a
/// test status, `subtests` an array of {name, status} with subtest statuses.
/// wptreport.py's summarize() indexes exactly these fields.
pub fn validateResult(v: std.json.Value) ResultError!ResultInfo {
    if (v != .object) return error.ResultNotAnObject;
    const t = v.object.get("test") orelse return error.TestIdMissing;
    if (t != .string) return error.TestIdMissing;
    if (!std.mem.startsWith(u8, t.string, "/")) return error.TestIdNotAbsolute;
    const s = v.object.get("status") orelse return error.StatusMissing;
    if (s != .string) return error.StatusMissing;
    if (!isOneOf(s.string, &test_statuses)) return error.UnknownTestStatus;
    const subs = v.object.get("subtests") orelse return error.SubtestsMissing;
    if (subs != .array) return error.SubtestsMissing;
    var passed: usize = 0;
    for (subs.array.items) |sub| {
        if (sub != .object) return error.SubtestNotAnObject;
        const n = sub.object.get("name") orelse return error.SubtestNameMissing;
        if (n != .string) return error.SubtestNameMissing;
        const ss = sub.object.get("status") orelse return error.UnknownSubtestStatus;
        if (ss != .string or !isOneOf(ss.string, &subtest_statuses)) return error.UnknownSubtestStatus;
        if (std.mem.eql(u8, ss.string, "PASS")) passed += 1;
    }
    return .{ .test_id = t.string, .status = s.string, .subtests = subs.array.items.len, .passed = passed };
}

/// The run_info fields a package carries. wpt.fyi requires product,
/// browser_version, os and revision; the rest are optional.
pub const RunInfo = struct {
    product: []const u8 = "",
    browser_version: []const u8 = "",
    os: []const u8 = "",
    os_version: []const u8 = "",
    processor: []const u8 = "",
    revision: []const u8 = "",

    fn field(self: *RunInfo, name: []const u8) ?*[]const u8 {
        inline for (@typeInfo(RunInfo).@"struct".fields) |f| {
            if (std.mem.eql(u8, f.name, name)) return &@field(self, f.name);
        }
        return null;
    }
};

// ============================================================================
// The manifest: source <-> URLs
// ============================================================================

pub const Manifest = struct {
    /// source path -> its URLs (no leading '/').
    urls_of: std.StringHashMapUnmanaged(std.ArrayList([]const u8)) = .empty,
    /// URL (no leading '/') -> source path.
    source_of: std.StringHashMapUnmanaged([]const u8) = .empty,

    /// Read items.testharness out of MANIFEST.json. Everything lives in `arena`.
    pub fn parse(arena: Allocator, scratch: Allocator, bytes: []const u8) !Manifest {
        var m: Manifest = .{};
        const parsed = try std.json.parseFromSlice(std.json.Value, scratch, bytes, .{});
        defer parsed.deinit();
        const items = parsed.value.object.get("items") orelse return error.ManifestHasNoItems;
        const th = items.object.get("testharness") orelse return error.ManifestHasNoTestharness;
        try m.walk(arena, "", th);
        return m;
    }

    fn walk(m: *Manifest, arena: Allocator, prefix: []const u8, node: std.json.Value) !void {
        switch (node) {
            .object => |obj| {
                var it = obj.iterator();
                while (it.next()) |e| {
                    const p = if (prefix.len == 0)
                        try arena.dupe(u8, e.key_ptr.*)
                    else
                        try std.fmt.allocPrint(arena, "{s}/{s}", .{ prefix, e.key_ptr.* });
                    try m.walk(arena, p, e.value_ptr.*);
                }
            },
            .array => |arr| {
                // [hash, [url or null, extras], ...]
                if (arr.items.len < 2) return;
                var list: std.ArrayList([]const u8) = .empty;
                for (arr.items[1..]) |entry| {
                    if (entry != .array or entry.array.items.len == 0) continue;
                    const u = entry.array.items[0];
                    const url = switch (u) {
                        .string => |s| try arena.dupe(u8, std.mem.trimStart(u8, s, "/")),
                        .null => prefix,
                        else => continue,
                    };
                    try list.append(arena, url);
                    try m.source_of.put(arena, url, prefix);
                }
                try m.urls_of.put(arena, prefix, list);
            },
            else => {},
        }
    }

    pub fn sourceOfTestId(m: *const Manifest, test_id: []const u8) ?[]const u8 {
        return m.source_of.get(std.mem.trimStart(u8, test_id, "/"));
    }
};

// ============================================================================
// Building a package
// ============================================================================

pub const Origin = enum { report, stream, crash, timeout };

const Entry = struct {
    /// The result object as compact JSON, no trailing newline.
    line: []const u8,
    origin: Origin,
    /// Index into `Package.chunks` of the input directory it came from.
    chunk: u32,
    mtime: i96,
    status: []const u8,
    subtests: usize,
    passed: usize,
};

pub const ChunkStats = struct {
    name: []const u8,
    from_reports: usize = 0,
    from_streams: usize = 0,
    crashed: usize = 0,
    timed_out: usize = 0,
    urls_not_run: usize = 0,
};

pub const Counters = struct {
    crane_dropped: usize = 0,
    duplicates_resolved: usize = 0,
    stream_lines_dropped: usize = 0,
    stream_lines_recovered: usize = 0,
    journal_lines_dropped: usize = 0,
    utf8_repaired: usize = 0,
    /// Journal records with no results that were neither CRASH nor TIMEOUT:
    /// counted, never synthesized.
    journal_only: usize = 0,
    reports: usize = 0,
    streams: usize = 0,
    journals: usize = 0,
};

pub const Package = struct {
    arena_state: std.heap.ArenaAllocator,
    /// For short-lived parse trees, freed as soon as a line is read.
    gpa: Allocator,
    entries: std.StringHashMapUnmanaged(Entry) = .empty,
    chunks: std.ArrayList(ChunkStats) = .empty,
    run_info: ?RunInfo = null,
    run_info_conflicts: std.ArrayList([]const u8) = .empty,
    time_start: ?i64 = null,
    time_end: ?i64 = null,
    /// source -> (journal status, chunk).
    journal: std.StringHashMapUnmanaged(struct { status: []const u8, chunk: u32 }) = .empty,
    counters: Counters = .{},

    pub fn init(gpa: Allocator) Package {
        return .{ .arena_state = .init(gpa), .gpa = gpa };
    }

    pub fn deinit(self: *Package) void {
        self.arena_state.deinit();
    }

    fn arena(self: *Package) Allocator {
        return self.arena_state.allocator();
    }

    pub fn chunkIndex(self: *Package, name: []const u8) !u32 {
        for (self.chunks.items, 0..) |c, i| if (std.mem.eql(u8, c.name, name)) return @intCast(i);
        try self.chunks.append(self.arena(), .{ .name = try self.arena().dupe(u8, name) });
        return @intCast(self.chunks.items.len - 1);
    }

    /// Record one result object (already parsed) from `origin`.
    fn addValue(self: *Package, v: std.json.Value, origin: Origin, chunk: u32, mtime: i96) !void {
        const info = try validateResult(v);
        if (isCraneTest(info.test_id)) {
            self.counters.crane_dropped += 1;
            return;
        }
        const line = try std.json.Stringify.valueAlloc(self.arena(), v, .{});
        const entry: Entry = .{
            .line = line,
            .origin = origin,
            .chunk = chunk,
            .mtime = mtime,
            .status = try self.arena().dupe(u8, info.status),
            .subtests = info.subtests,
            .passed = info.passed,
        };
        const gop = try self.entries.getOrPut(self.arena(), info.test_id);
        if (!gop.found_existing) {
            gop.key_ptr.* = try self.arena().dupe(u8, info.test_id);
            gop.value_ptr.* = entry;
            return;
        }
        const old = gop.value_ptr.*;
        // A finished child's report and its stream hold the same result; the
        // report is the one the child completed, so it wins without counting
        // as a duplicate. Two files of the same kind: a re-run - the newer one.
        if (old.origin == .report and origin == .stream) return;
        if (old.origin == .stream and origin == .report) {
            gop.value_ptr.* = entry;
            return;
        }
        self.counters.duplicates_resolved += 1;
        if (mtime > old.mtime) gop.value_ptr.* = entry;
    }

    fn parseRepaired(self: *Package, bytes: []const u8) !std.json.Parsed(std.json.Value) {
        const repaired = try repairUtf8(self.gpa, bytes);
        defer if (repaired) |r| self.gpa.free(r);
        if (repaired != null) self.counters.utf8_repaired += 1;
        return std.json.parseFromSlice(std.json.Value, self.gpa, repaired orelse bytes, .{});
    }

    /// A finished child's `wptreport*.json`.
    pub fn addReport(self: *Package, bytes: []const u8, chunk: u32, mtime: i96) !void {
        self.counters.reports += 1;
        const parsed = try self.parseRepaired(bytes);
        defer parsed.deinit();
        const root = parsed.value;
        if (root != .object) return error.ReportNotAnObject;
        const results = root.object.get("results") orelse return error.ReportHasNoResults;
        if (results != .array) return error.ReportHasNoResults;

        if (root.object.get("run_info")) |ri| try self.mergeRunInfo(ri);
        if (root.object.get("time_start")) |t| {
            if (t == .integer) self.time_start = if (self.time_start) |s| @min(s, t.integer) else t.integer;
        }
        if (root.object.get("time_end")) |t| {
            if (t == .integer) self.time_end = if (self.time_end) |s| @max(s, t.integer) else t.integer;
        }
        for (results.array.items) |r| try self.addValue(r, .report, chunk, mtime);
    }

    /// Every report must describe the same run: wpt.fyi refuses chunks whose
    /// run_info disagrees (ConflictingDataError).
    fn mergeRunInfo(self: *Package, ri: std.json.Value) !void {
        if (ri != .object) return error.RunInfoNotAnObject;
        var incoming: RunInfo = .{};
        var it = ri.object.iterator();
        while (it.next()) |e| {
            if (e.value_ptr.* != .string) continue;
            if (incoming.field(e.key_ptr.*)) |f| f.* = try self.arena().dupe(u8, e.value_ptr.string);
        }
        const have = self.run_info orelse {
            self.run_info = incoming;
            return;
        };
        inline for (@typeInfo(RunInfo).@"struct".fields) |f| {
            if (!std.mem.eql(u8, @field(have, f.name), @field(incoming, f.name))) {
                try self.run_info_conflicts.append(self.arena(), try std.fmt.allocPrint(
                    self.arena(),
                    "{s}: \"{s}\" vs \"{s}\"",
                    .{ f.name, @field(have, f.name), @field(incoming, f.name) },
                ));
            }
        }
    }

    /// A `*.wptreport.jsonl` result stream. A line that does not parse is a
    /// crash mid-write: if a later record starts inside it (the restarted
    /// child appended after the fragment), that record is kept; the fragment
    /// is dropped and counted.
    pub fn addStream(self: *Package, bytes: []const u8, chunk: u32, mtime: i96) !void {
        self.counters.streams += 1;
        var lines = std.mem.splitScalar(u8, bytes, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \r");
            if (line.len == 0) continue;
            if (self.parseRepaired(line)) |parsed| {
                defer parsed.deinit();
                try self.addValue(parsed.value, .stream, chunk, mtime);
                continue;
            } else |_| {}
            self.counters.stream_lines_dropped += 1;
            const marker = "{\"test\": ";
            if (std.mem.lastIndexOf(u8, line, marker)) |at| {
                if (at == 0) continue;
                if (self.parseRepaired(line[at..])) |parsed| {
                    defer parsed.deinit();
                    try self.addValue(parsed.value, .stream, chunk, mtime);
                    self.counters.stream_lines_recovered += 1;
                } else |_| {}
            }
        }
    }

    /// A runner journal: which source ended how. Only used for files that
    /// left no results.
    pub fn addJournal(self: *Package, bytes: []const u8, chunk: u32) !void {
        self.counters.journals += 1;
        var lines = std.mem.splitScalar(u8, bytes, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \r");
            if (line.len == 0) continue;
            const parsed = std.json.parseFromSlice(std.json.Value, self.gpa, line, .{}) catch {
                self.counters.journal_lines_dropped += 1;
                continue;
            };
            defer parsed.deinit();
            const obj = if (parsed.value == .object) parsed.value.object else continue;
            const path = obj.get("path") orelse continue;
            const status = obj.get("status") orelse continue;
            if (path != .string or status != .string) continue;
            const gop = try self.journal.getOrPut(self.arena(), path.string);
            if (!gop.found_existing) gop.key_ptr.* = try self.arena().dupe(u8, path.string);
            // A CRASH record is final for its file; keep it over an earlier one.
            if (gop.found_existing and std.mem.eql(u8, gop.value_ptr.status, "CRASH")) continue;
            gop.value_ptr.* = .{ .status = try self.arena().dupe(u8, status.string), .chunk = chunk };
        }
    }

    /// Give every journalled source that left no result - a crash, or a stall
    /// kill - wptrunner's result for it in each global the runner implements.
    pub fn synthesizeMissing(self: *Package, manifest: *const Manifest) !void {
        var it = self.journal.iterator();
        while (it.next()) |e| {
            const source = e.key_ptr.*;
            if (std.mem.startsWith(u8, source, "crane/")) continue;
            const urls = manifest.urls_of.get(source) orelse {
                self.counters.journal_only += 1;
                continue;
            };
            var any = false;
            for (urls.items) |u| {
                if (self.hasResult(u)) any = true;
            }
            if (any) continue;
            const origin: Origin = if (std.mem.eql(u8, e.value_ptr.status, "CRASH"))
                .crash
            else if (std.mem.eql(u8, e.value_ptr.status, "TIMEOUT"))
                .timeout
            else {
                self.counters.journal_only += 1;
                continue;
            };
            for (urls.items) |u| {
                if (UrlGlobal.of(u) != .runs) continue;
                const test_id = try std.fmt.allocPrint(self.arena(), "/{s}", .{u});
                const line = try synthesizedLine(self.arena(), test_id, origin);
                try self.entries.put(self.arena(), test_id, .{
                    .line = line,
                    .origin = origin,
                    .chunk = e.value_ptr.chunk,
                    .mtime = 0,
                    .status = if (origin == .crash) "CRASH" else "TIMEOUT",
                    .subtests = 0,
                    .passed = 0,
                });
            }
        }
    }

    fn hasResult(self: *Package, url_no_slash: []const u8) bool {
        var buf: [4096]u8 = undefined;
        const id = std.fmt.bufPrint(&buf, "/{s}", .{url_no_slash}) catch return false;
        return self.entries.contains(id);
    }

    /// Per-chunk and overall accounting against the manifest.
    pub fn tally(self: *Package, manifest: *const Manifest) !Tally {
        var t: Tally = .{};
        // source -> origin class, so a source counts once.
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        defer seen.deinit(self.gpa);
        var it = self.entries.iterator();
        while (it.next()) |e| {
            const v = e.value_ptr.*;
            t.tests += 1;
            t.subtests += v.subtests;
            t.passed += v.passed;
            if (std.mem.eql(u8, v.status, "OK")) t.ok += 1 else if (std.mem.eql(u8, v.status, "ERROR")) t.err += 1 else if (std.mem.eql(u8, v.status, "TIMEOUT")) t.timeout += 1 else if (std.mem.eql(u8, v.status, "CRASH")) t.crash += 1 else t.other += 1;

            const source = manifest.sourceOfTestId(e.key_ptr.*) orelse {
                t.not_in_manifest += 1;
                continue;
            };
            if (seen.contains(source)) continue;
            try seen.put(self.gpa, source, {});
            const c = &self.chunks.items[v.chunk];
            switch (self.classify(manifest, source)) {
                .report => c.from_reports += 1,
                .stream => c.from_streams += 1,
                .crash => c.crashed += 1,
                .timeout => c.timed_out += 1,
            }
            if (manifest.urls_of.get(source)) |urls| {
                for (urls.items) |u| {
                    if (self.hasResult(u)) continue;
                    c.urls_not_run += 1;
                    switch (UrlGlobal.of(u)) {
                        .runs => t.not_run_other += 1,
                        .sharedworker => t.not_run_sharedworker += 1,
                        .serviceworker => t.not_run_serviceworker += 1,
                        .shadowrealm => t.not_run_shadowrealm += 1,
                    }
                }
            }
        }
        var sit = manifest.urls_of.keyIterator();
        while (sit.next()) |k| {
            if (seen.contains(k.*)) continue;
            if (std.mem.startsWith(u8, k.*, "crane/")) continue;
            t.sources_never_run += 1;
        }
        return t;
    }

    /// A source's class: synthesized if its results were, else report if any
    /// URL came from a finished report, else stream.
    fn classify(self: *Package, manifest: *const Manifest, source: []const u8) Origin {
        var best: Origin = .stream;
        const urls = manifest.urls_of.get(source) orelse return best;
        var buf: [4096]u8 = undefined;
        for (urls.items) |u| {
            const id = std.fmt.bufPrint(&buf, "/{s}", .{u}) catch continue;
            const e = self.entries.get(id) orelse continue;
            switch (e.origin) {
                .crash, .timeout => return e.origin,
                .report => best = .report,
                .stream => {},
            }
        }
        return best;
    }

    /// The run_info to upload, or an error saying why there is none.
    pub fn finalRunInfo(self: *Package, crane_commit: ?[]const u8) !RunInfo {
        if (self.run_info_conflicts.items.len > 0) return error.RunInfoConflicts;
        var ri = self.run_info orelse return error.NoCompleteReport;
        if (ri.product.len == 0) return error.RunInfoProductMissing;
        if (ri.os.len == 0) return error.RunInfoOsMissing;
        if (!isFullSha(ri.revision)) return error.RunInfoRevisionNotAFullSha;
        ri.browser_version = try resolveBrowserVersion(self.arena(), ri.browser_version, crane_commit);
        return ri;
    }

    /// Test IDs in upload order.
    pub fn sortedIds(self: *Package) ![][]const u8 {
        const ids = try self.arena().alloc([]const u8, self.entries.count());
        var i: usize = 0;
        var it = self.entries.keyIterator();
        while (it.next()) |k| : (i += 1) ids[i] = k.*;
        std.mem.sort([]const u8, ids, {}, struct {
            fn lt(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.lt);
        return ids;
    }

    /// Serialize the package into wptreport chunks of at most `max_bytes`
    /// uncompressed JSON each (at least one result per chunk). Returns each
    /// chunk's JSON; the caller gzips and writes them.
    pub fn renderChunks(self: *Package, run_info: RunInfo, max_bytes: usize) ![][]u8 {
        const ids = try self.sortedIds();
        var out: std.ArrayList([]u8) = .empty;
        var i: usize = 0;
        while (i < ids.len or (ids.len == 0 and out.items.len == 0)) {
            var aw: std.Io.Writer.Allocating = .init(self.gpa);
            defer aw.deinit();
            const w = &aw.writer;
            try w.writeAll("{\"run_info\": ");
            try std.json.Stringify.value(run_info, .{}, w);
            if (self.time_start) |t| try w.print(", \"time_start\": {d}", .{t});
            if (self.time_end) |t| try w.print(", \"time_end\": {d}", .{t});
            try w.writeAll(", \"results\": [\n");
            var first = true;
            while (i < ids.len) {
                const line = self.entries.get(ids[i]).?.line;
                if (!first and aw.written().len + line.len > max_bytes) break;
                if (!first) try w.writeAll(",\n");
                try w.writeAll(line);
                first = false;
                i += 1;
            }
            try w.writeAll("\n]}\n");
            try out.append(self.arena(), try self.arena().dupe(u8, aw.written()));
            if (ids.len == 0) break;
        }
        return out.toOwnedSlice(self.arena());
    }
};

pub const Tally = struct {
    tests: usize = 0,
    subtests: usize = 0,
    passed: usize = 0,
    ok: usize = 0,
    err: usize = 0,
    timeout: usize = 0,
    crash: usize = 0,
    other: usize = 0,
    not_in_manifest: usize = 0,
    not_run_sharedworker: usize = 0,
    not_run_serviceworker: usize = 0,
    not_run_shadowrealm: usize = 0,
    not_run_other: usize = 0,
    sources_never_run: usize = 0,
};

/// The result wptrunner reports for a test it lost: CRASH with no message, or
/// (a forced kill) TIMEOUT with its external-timeout message; no subtests.
pub fn synthesizedLine(allocator: Allocator, test_id: []const u8, origin: Origin) ![]u8 {
    const status: []const u8, const message: ?[]const u8 = switch (origin) {
        .crash => .{ "CRASH", null },
        .timeout => .{ "TIMEOUT", external_timeout_message },
        .report, .stream => unreachable,
    };
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    try aw.writer.writeAll("{\"test\": ");
    try std.json.Stringify.value(test_id, .{}, &aw.writer);
    try aw.writer.writeAll(", \"status\": ");
    try std.json.Stringify.value(status, .{}, &aw.writer);
    try aw.writer.writeAll(", \"message\": ");
    try std.json.Stringify.value(message, .{}, &aw.writer);
    try aw.writer.writeAll(", \"subtests\": []}");
    return aw.toOwnedSlice();
}

// ============================================================================
// gzip
// ============================================================================

pub fn gzip(allocator: Allocator, data: []const u8) ![]u8 {
    var out: std.Io.Writer.Allocating = try .initCapacity(allocator, @max(64, data.len / 4));
    errdefer out.deinit();
    const window = try allocator.alloc(u8, std.compress.flate.max_window_len);
    defer allocator.free(window);
    const c = try allocator.create(std.compress.flate.Compress);
    defer allocator.destroy(c);
    c.* = try .init(&out.writer, window, .gzip, .default);
    try c.writer.writeAll(data);
    try c.finish();
    return out.toOwnedSlice();
}

pub fn gunzip(allocator: Allocator, data: []const u8) ![]u8 {
    var in: std.Io.Reader = .fixed(data);
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    var d: std.compress.flate.Decompress = .init(&in, .gzip, &.{});
    _ = try d.reader.streamRemaining(&out.writer);
    return out.toOwnedSlice();
}

// ============================================================================
// check: a dry run of wpt.fyi's checks over written chunks
// ============================================================================

pub const CheckResult = struct {
    files: usize = 0,
    results: usize = 0,
    subtests: usize = 0,
    problems: std.ArrayList([]const u8) = .empty,
};

/// Apply wptreport.py's checks to the decompressed chunks: each is JSON with
/// a `results` array of valid results; run_info agrees across chunks and has
/// product, browser_version (naming a commit), os and a full revision; no
/// test ID appears twice across the package (summarize() raises
/// ConflictingDataError); and no Crane test is included.
pub fn checkChunks(arena: Allocator, chunks: []const []const u8) !CheckResult {
    var res: CheckResult = .{};
    var ids: std.StringHashMapUnmanaged(void) = .empty;
    var first_run_info: ?[]const u8 = null;
    for (chunks, 0..) |json, n| {
        res.files += 1;
        if (!std.unicode.utf8ValidateSlice(json)) {
            try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: not valid UTF-8", .{n}));
            continue;
        }
        const parsed = std.json.parseFromSlice(std.json.Value, arena, json, .{}) catch {
            try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: not JSON", .{n}));
            continue;
        };
        const root = parsed.value;
        const results = if (root == .object) root.object.get("results") else null;
        if (results == null or results.? != .array) {
            try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: no results array", .{n}));
            continue;
        }
        const ri = root.object.get("run_info") orelse {
            try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: no run_info", .{n}));
            continue;
        };
        for ([_][]const u8{ "product", "browser_version", "os", "revision" }) |k| {
            const v = if (ri == .object) ri.object.get(k) else null;
            if (v == null or v.? != .string or v.?.string.len == 0)
                try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: run_info.{s} missing", .{ n, k }));
        }
        if (ri == .object) {
            if (ri.object.get("revision")) |r| if (r != .string or !isFullSha(r.string))
                try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: run_info.revision is not a 40-hex commit", .{n}));
            if (ri.object.get("browser_version")) |b| if (b == .string and std.mem.indexOfScalar(u8, b.string, '+') == null)
                try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: browser_version \"{s}\" names no Crane commit", .{ n, b.string }));
        }
        const ri_json = try std.json.Stringify.valueAlloc(arena, ri, .{});
        if (first_run_info) |f| {
            if (!std.mem.eql(u8, f, ri_json))
                try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: run_info differs from chunk 0", .{n}));
        } else first_run_info = ri_json;
        for (results.?.array.items) |r| {
            const info = validateResult(r) catch |err| {
                try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: {s}", .{ n, @errorName(err) }));
                continue;
            };
            res.results += 1;
            res.subtests += info.subtests;
            if (isCraneTest(info.test_id))
                try res.problems.append(arena, try std.fmt.allocPrint(arena, "chunk {d}: Crane test {s}", .{ n, info.test_id }));
            const gop = try ids.getOrPut(arena, info.test_id);
            if (gop.found_existing)
                try res.problems.append(arena, try std.fmt.allocPrint(arena, "duplicate test {s}", .{info.test_id}));
        }
    }
    return res;
}

// ============================================================================
// Command line
// ============================================================================

fn usage() noreturn {
    std.debug.print(
        \\usage: wpt_upload_package build --input=<sweep dir> --manifest=<MANIFEST.json> --out=<dir>
        \\                                [--crane-commit=<sha>] [--max-chunk-mb=64]
        \\       wpt_upload_package check <chunk.json.gz>...
        \\
    , .{});
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    var arena_state: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    const cmd = args.next() orelse usage();

    var stdout_buf: [64 * 1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    if (std.mem.eql(u8, cmd, "check")) {
        var chunks: std.ArrayList([]const u8) = .empty;
        while (args.next()) |path| {
            const gz = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(1 << 32));
            const json = gunzip(arena, gz) catch {
                std.debug.print("{s}: not gzip\n", .{path});
                std.process.exit(1);
            };
            try chunks.append(arena, json);
        }
        if (chunks.items.len == 0) usage();
        const res = try checkChunks(arena, chunks.items);
        try out.print("checked {d} chunk(s): {d} results, {d} subtests, {d} problem(s)\n", .{ res.files, res.results, res.subtests, res.problems.items.len });
        for (res.problems.items) |p| try out.print("  {s}\n", .{p});
        try out.flush();
        if (res.problems.items.len > 0) std.process.exit(1);
        return;
    }
    if (!std.mem.eql(u8, cmd, "build")) usage();

    var input: ?[]const u8 = null;
    var manifest_path: ?[]const u8 = null;
    var out_dir: ?[]const u8 = null;
    var crane_commit: ?[]const u8 = null;
    var max_mb: usize = 64;
    while (args.next()) |a| {
        if (std.mem.startsWith(u8, a, "--input=")) input = a["--input=".len..] else if (std.mem.startsWith(u8, a, "--manifest=")) manifest_path = a["--manifest=".len..] else if (std.mem.startsWith(u8, a, "--out=")) out_dir = a["--out=".len..] else if (std.mem.startsWith(u8, a, "--crane-commit=")) crane_commit = a["--crane-commit=".len..] else if (std.mem.startsWith(u8, a, "--max-chunk-mb=")) max_mb = try std.fmt.parseInt(usize, a["--max-chunk-mb=".len..], 10) else usage();
    }
    const input_dir = input orelse usage();
    const out_path = out_dir orelse usage();

    const manifest_bytes = try std.Io.Dir.cwd().readFileAlloc(io, manifest_path orelse usage(), arena, .limited(1 << 30));
    const manifest = try Manifest.parse(arena, init.gpa, manifest_bytes);

    var pkg: Package = .init(init.gpa);
    defer pkg.deinit();

    var dir = try std.Io.Dir.cwd().openDir(io, input_dir, .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |e| {
        if (e.kind != .file) continue;
        const base = e.basename;
        const is_stream = std.mem.endsWith(u8, base, ".wptreport.jsonl");
        const is_report = std.mem.startsWith(u8, base, "wptreport") and std.mem.endsWith(u8, base, ".json");
        const is_journal = !is_stream and std.mem.startsWith(u8, base, "journal") and std.mem.endsWith(u8, base, ".jsonl");
        if (!is_stream and !is_report and !is_journal) continue;
        const chunk = try pkg.chunkIndex(std.fs.path.dirname(e.path) orelse ".");
        const stat = try dir.statFile(io, e.path, .{});
        const bytes = try dir.readFileAlloc(io, e.path, init.gpa, .limited(1 << 32));
        defer init.gpa.free(bytes);
        if (is_stream) {
            try pkg.addStream(bytes, chunk, stat.mtime.nanoseconds);
        } else if (is_report) {
            pkg.addReport(bytes, chunk, stat.mtime.nanoseconds) catch |err| {
                std.debug.print("{s}/{s}: {s}\n", .{ input_dir, e.path, @errorName(err) });
                return err;
            };
        } else {
            try pkg.addJournal(bytes, chunk);
        }
    }
    try pkg.synthesizeMissing(&manifest);

    const run_info = pkg.finalRunInfo(crane_commit) catch |err| {
        std.debug.print("NOT UPLOADABLE: {s}\n", .{@errorName(err)});
        for (pkg.run_info_conflicts.items) |c| std.debug.print("  run_info conflict: {s}\n", .{c});
        std.process.exit(1);
    };
    const t = try pkg.tally(&manifest);
    const chunks = try pkg.renderChunks(run_info, max_mb << 20);

    // Every chunk must pass the same check `check` applies, before it is written.
    const res = try checkChunks(arena, chunks);
    if (res.problems.items.len > 0) {
        for (res.problems.items) |p| std.debug.print("  {s}\n", .{p});
        std.debug.print("NOT UPLOADABLE: {d} problem(s)\n", .{res.problems.items.len});
        std.process.exit(1);
    }

    try std.Io.Dir.cwd().createDirPath(io, out_path);
    var gz_total: usize = 0;
    for (chunks, 0..) |json, n| {
        const gz = try gzip(arena, json);
        gz_total += gz.len;
        const name = try std.fmt.allocPrint(arena, "{s}/wptreport-crane-{s}-{d:0>3}.json.gz", .{ out_path, run_info.revision[0..10], n });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = name, .data = gz });
    }

    var summary: std.Io.Writer.Allocating = .init(arena);
    const s = &summary.writer;
    try s.print("wpt.fyi upload package from {s}\n", .{input_dir});
    try s.print("run_info: product {s}, browser_version {s}, os {s} {s}, processor {s}, revision {s}\n", .{ run_info.product, run_info.browser_version, run_info.os, run_info.os_version, run_info.processor, run_info.revision });
    try s.print("chunks: {d} file(s), {d} bytes gzipped (max {d} MiB uncompressed each)\n", .{ chunks.len, gz_total, max_mb });
    try s.print("inputs: {d} report(s), {d} stream(s), {d} journal(s)\n", .{ pkg.counters.reports, pkg.counters.streams, pkg.counters.journals });
    try s.print("tests (URLs): {d}  OK {d}  ERROR {d}  TIMEOUT {d}  CRASH {d}  other {d}\n", .{ t.tests, t.ok, t.err, t.timeout, t.crash, t.other });
    try s.print("subtests: {d}, passing {d}\n", .{ t.subtests, t.passed });
    try s.print("URLs not run in sources that ran (wpt.fyi shows them missing): sharedworker {d}, serviceworker {d}, shadowrealm {d}, other {d}\n", .{ t.not_run_sharedworker, t.not_run_serviceworker, t.not_run_shadowrealm, t.not_run_other });
    try s.print("manifest sources with no result at all: {d} (not in this sweep, or no runner file type)\n", .{t.sources_never_run});
    try s.print("dropped: Crane tests {d}; duplicates resolved {d}; unreadable stream lines {d} ({d} records recovered from them); unreadable journal lines {d}; results with invalid UTF-8 repaired {d}; results not in the manifest {d}\n", .{ pkg.counters.crane_dropped, pkg.counters.duplicates_resolved, pkg.counters.stream_lines_dropped, pkg.counters.stream_lines_recovered, pkg.counters.journal_lines_dropped, pkg.counters.utf8_repaired, t.not_in_manifest });
    try s.print("journal records with no results, not CRASH/TIMEOUT (not synthesized): {d}\n", .{pkg.counters.journal_only});
    try s.print("\nper input directory (source files):\n{s: <40} {s: >8} {s: >8} {s: >8} {s: >8} {s: >12}\n", .{ "chunk", "report", "stream", "crashed", "timeout", "URLs not run" });
    var totals: ChunkStats = .{ .name = "total" };
    for (pkg.chunks.items) |c| {
        try s.print("{s: <40} {d: >8} {d: >8} {d: >8} {d: >8} {d: >12}\n", .{ c.name, c.from_reports, c.from_streams, c.crashed, c.timed_out, c.urls_not_run });
        totals.from_reports += c.from_reports;
        totals.from_streams += c.from_streams;
        totals.crashed += c.crashed;
        totals.timed_out += c.timed_out;
        totals.urls_not_run += c.urls_not_run;
    }
    try s.print("{s: <40} {d: >8} {d: >8} {d: >8} {d: >8} {d: >12}\n", .{ totals.name, totals.from_reports, totals.from_streams, totals.crashed, totals.timed_out, totals.urls_not_run });
    try s.print("\ncheck: {d} chunk(s), {d} results, {d} subtests, 0 problems\n", .{ res.files, res.results, res.subtests });

    const summary_path = try std.fmt.allocPrint(arena, "{s}/summary.txt", .{out_path});
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = summary_path, .data = summary.written() });
    try out.writeAll(summary.written());
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const test_manifest =
    \\{"version": 9, "items": {"testharness": {
    \\  "url": {"a.any.js": ["h", ["url/a.any.html", {}], ["url/a.any.worker.html", {}],
    \\                            ["url/a.any.sharedworker.html", {}], ["url/a.any.serviceworker.html", {}]],
    \\          "b.html": ["h", [null, {}]],
    \\          "c.html": ["h", [null, {}]],
    \\          "d.html": ["h", [null, {}]]},
    \\  "crane": {"x.html": ["h", [null, {}]]},
    \\  "svg": {"s.svg": ["h", [null, {}]]}
    \\}}}
;

const run_info_json =
    \\{"product": "crane", "browser_version": "0.1.0-dev", "os": "mac", "os_version": "27.0", "processor": "arm64", "revision": "afe89a5df4dcc7c6bcb317b07d6eee31a383c466"}
;

fn reportJson(allocator: Allocator, results: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{{\"run_info\": {s}, \"time_start\": 100, \"time_end\": 200, \"results\": [{s}]}}", .{ run_info_json, results });
}

const result_a_window =
    \\{"test": "/url/a.any.html", "status": "OK", "message": null, "subtests": [{"name": "one", "status": "PASS", "message": null}, {"name": "two", "status": "FAIL", "message": "x"}]}
;
const result_a_worker =
    \\{"test": "/url/a.any.worker.html", "status": "OK", "message": null, "subtests": [{"name": "one", "status": "PASS", "message": null}]}
;
const result_b =
    \\{"test": "/url/b.html", "status": "TIMEOUT", "message": null, "subtests": []}
;
const result_crane =
    \\{"test": "/crane/x.html", "status": "OK", "message": null, "subtests": []}
;

fn testPackage(allocator: Allocator) !struct { pkg: Package, manifest_arena: std.heap.ArenaAllocator, manifest: Manifest } {
    var ma: std.heap.ArenaAllocator = .init(allocator);
    errdefer ma.deinit();
    const manifest = try Manifest.parse(ma.allocator(), allocator, test_manifest);
    return .{ .pkg = .init(allocator), .manifest_arena = ma, .manifest = manifest };
}

test "the manifest maps sources to URLs and back" {
    var ma: std.heap.ArenaAllocator = .init(testing.allocator);
    defer ma.deinit();
    const m = try Manifest.parse(ma.allocator(), testing.allocator, test_manifest);
    try testing.expectEqual(@as(usize, 4), m.urls_of.get("url/a.any.js").?.items.len);
    try testing.expectEqualStrings("url/a.any.js", m.sourceOfTestId("/url/a.any.worker.html").?);
    try testing.expectEqualStrings("url/b.html", m.sourceOfTestId("/url/b.html").?);
}

test "UrlGlobal names the globals the runner does not implement" {
    try testing.expectEqual(UrlGlobal.runs, UrlGlobal.of("url/a.any.html"));
    try testing.expectEqual(UrlGlobal.runs, UrlGlobal.of("url/a.any.worker.html?x=1"));
    try testing.expectEqual(UrlGlobal.runs, UrlGlobal.of("url/a.any.worker-module.html"));
    try testing.expectEqual(UrlGlobal.runs, UrlGlobal.of("url/a.any.sharedworker-module.html"));
    try testing.expectEqual(UrlGlobal.runs, UrlGlobal.of("dom/x.window.html"));
    try testing.expectEqual(UrlGlobal.sharedworker, UrlGlobal.of("url/a.any.sharedworker.html"));
    try testing.expectEqual(UrlGlobal.serviceworker, UrlGlobal.of("url/a.any.serviceworker.html"));
    try testing.expectEqual(UrlGlobal.serviceworker, UrlGlobal.of("url/a.any.serviceworker-module.html"));
    try testing.expectEqual(UrlGlobal.shadowrealm, UrlGlobal.of("url/a.any.shadowrealm-in-window.html"));
}

test "validateResult accepts wptreport results and rejects what wpt.fyi would" {
    const ok = try std.json.parseFromSlice(std.json.Value, testing.allocator, result_a_window, .{});
    defer ok.deinit();
    const info = try validateResult(ok.value);
    try testing.expectEqualStrings("/url/a.any.html", info.test_id);
    try testing.expectEqual(@as(usize, 2), info.subtests);
    try testing.expectEqual(@as(usize, 1), info.passed);

    const cases = [_]struct { []const u8, ResultError }{
        .{ "{\"test\": \"url/a.html\", \"status\": \"OK\", \"subtests\": []}", error.TestIdNotAbsolute },
        .{ "{\"test\": \"/a.html\", \"status\": \"PASSED\", \"subtests\": []}", error.UnknownTestStatus },
        .{ "{\"test\": \"/a.html\", \"status\": \"OK\"}", error.SubtestsMissing },
        .{ "{\"test\": \"/a.html\", \"status\": \"OK\", \"subtests\": [{\"status\": \"PASS\"}]}", error.SubtestNameMissing },
        .{ "{\"test\": \"/a.html\", \"status\": \"OK\", \"subtests\": [{\"name\": \"n\", \"status\": \"OK\"}]}", error.UnknownSubtestStatus },
    };
    for (cases) |c| {
        const p = try std.json.parseFromSlice(std.json.Value, testing.allocator, c[0], .{});
        defer p.deinit();
        try testing.expectError(c[1], validateResult(p.value));
    }
}

test "browser_version must name a Crane commit" {
    const a = testing.allocator;
    const filled = try resolveBrowserVersion(a, "0.1.0-dev", "93049ebc2aaaabbbbccccddddeeeeffff0000111");
    defer a.free(filled);
    try testing.expectEqualStrings("0.1.0-dev+93049ebc2", filled);
    const kept = try resolveBrowserVersion(a, "0.1.0-dev+93049ebc2", "93049ebc2aaaa");
    defer a.free(kept);
    try testing.expectEqualStrings("0.1.0-dev+93049ebc2", kept);
    const kept_alone = try resolveBrowserVersion(a, "0.1.0-dev+93049ebc2", null);
    defer a.free(kept_alone);
    try testing.expectError(error.BrowserVersionHasNoCommit, resolveBrowserVersion(a, "0.1.0-dev", null));
    try testing.expectError(error.CraneCommitMismatch, resolveBrowserVersion(a, "0.1.0-dev+93049ebc2", "12345678"));
}

test "invalid UTF-8 is repaired to U+FFFD, valid input is left alone" {
    const a = testing.allocator;
    try testing.expectEqual(@as(?[]u8, null), try repairUtf8(a, "caf\xc3\xa9"));
    const fixed = (try repairUtf8(a, "a\xffb\xc3")).?;
    defer a.free(fixed);
    try testing.expectEqualStrings("a\u{FFFD}b\u{FFFD}", fixed);
}

test "a finished report and its own stream count once, from the report" {
    var t = try testPackage(testing.allocator);
    defer t.pkg.deinit();
    defer t.manifest_arena.deinit();
    const report = try reportJson(testing.allocator, result_a_window ++ "," ++ result_a_worker ++ "," ++ result_crane);
    defer testing.allocator.free(report);

    const chunk = try t.pkg.chunkIndex("chunks/aaa");
    try t.pkg.addStream(result_a_window ++ "\n" ++ result_a_worker ++ "\n", chunk, 10);
    try t.pkg.addReport(report, chunk, 20);

    try testing.expectEqual(@as(usize, 2), t.pkg.entries.count());
    try testing.expectEqual(@as(usize, 0), t.pkg.counters.duplicates_resolved);
    try testing.expectEqual(@as(usize, 1), t.pkg.counters.crane_dropped);
    const tally_ = try t.pkg.tally(&t.manifest);
    try testing.expectEqual(@as(usize, 1), t.pkg.chunks.items[chunk].from_reports);
    try testing.expectEqual(@as(usize, 0), t.pkg.chunks.items[chunk].from_streams);
    // a.any.js ran in window and worker; its sharedworker and serviceworker
    // URLs are counted as not run, never given a result.
    try testing.expectEqual(@as(usize, 1), tally_.not_run_sharedworker);
    try testing.expectEqual(@as(usize, 1), tally_.not_run_serviceworker);
    try testing.expectEqual(@as(usize, 2), t.pkg.chunks.items[chunk].urls_not_run);
}

test "a crashed child: stream results kept, truncated line dropped, crashed file gets CRASH" {
    var t = try testPackage(testing.allocator);
    defer t.pkg.deinit();
    defer t.manifest_arena.deinit();
    const chunk = try t.pkg.chunkIndex("chunks/aab");

    // The first child finished a.any.js (two lines) and b.html, died writing
    // c.html's line, and the supervisor journalled d.html as the crash... then
    // the restarted child appended its own line after the fragment.
    const stream = result_a_window ++ "\n" ++ result_a_worker ++ "\n" ++ result_b ++ "\n" ++
        "{\"test\": \"/url/c.html\", \"status\": \"OK\", \"subt" ++
        "{\"test\": \"/url/c.html\", \"status\": \"ERROR\", \"message\": null, \"subtests\": []}\n";
    try t.pkg.addStream(stream, chunk, 10);
    try t.pkg.addJournal(
        \\{"index":0,"path":"url/a.any.js","status":"OK"}
        \\{"index":1,"path":"url/b.html","status":"TIMEOUT"}
        \\{"index":2,"path":"url/d.html","status":"CRASH"}
        \\{"index":3,"path":"url/c.html","status":"ERR
    , chunk);
    try t.pkg.synthesizeMissing(&t.manifest);

    try testing.expectEqual(@as(usize, 1), t.pkg.counters.stream_lines_dropped);
    try testing.expectEqual(@as(usize, 1), t.pkg.counters.stream_lines_recovered);
    try testing.expectEqual(@as(usize, 1), t.pkg.counters.journal_lines_dropped);
    // b.html has a real TIMEOUT result from the stream: not replaced.
    try testing.expect(std.mem.indexOf(u8, t.pkg.entries.get("/url/b.html").?.line, "external timeout") == null);
    const d = t.pkg.entries.get("/url/d.html").?;
    try testing.expectEqualStrings("CRASH", d.status);
    try testing.expectEqualStrings("{\"test\": \"/url/d.html\", \"status\": \"CRASH\", \"message\": null, \"subtests\": []}", d.line);

    _ = try t.pkg.tally(&t.manifest);
    try testing.expectEqual(@as(usize, 1), t.pkg.chunks.items[chunk].crashed);
    try testing.expectEqual(@as(usize, 3), t.pkg.chunks.items[chunk].from_streams);
}

test "a stall-killed .any.js gets TIMEOUT in the globals the runner runs, nothing in the others" {
    var t = try testPackage(testing.allocator);
    defer t.pkg.deinit();
    defer t.manifest_arena.deinit();
    const chunk = try t.pkg.chunkIndex(".");
    try t.pkg.addJournal("{\"index\":0,\"path\":\"url/a.any.js\",\"status\":\"TIMEOUT\"}\n", chunk);
    try t.pkg.synthesizeMissing(&t.manifest);

    try testing.expectEqual(@as(usize, 2), t.pkg.entries.count());
    const w = t.pkg.entries.get("/url/a.any.worker.html").?;
    try testing.expectEqualStrings("TIMEOUT", w.status);
    try testing.expect(std.mem.indexOf(u8, w.line, external_timeout_message) != null);
    try testing.expect(t.pkg.entries.get("/url/a.any.sharedworker.html") == null);
}

test "reports that disagree on run_info are not uploadable" {
    var t = try testPackage(testing.allocator);
    defer t.pkg.deinit();
    defer t.manifest_arena.deinit();
    const chunk = try t.pkg.chunkIndex(".");
    const r1 = try reportJson(testing.allocator, result_b);
    defer testing.allocator.free(r1);
    try t.pkg.addReport(r1, chunk, 1);
    const r2 = try std.mem.replaceOwned(u8, testing.allocator, r1, "\"os\": \"mac\"", "\"os\": \"linux\"");
    defer testing.allocator.free(r2);
    try t.pkg.addReport(r2, chunk, 2);
    try testing.expectError(error.RunInfoConflicts, t.pkg.finalRunInfo("93049ebc2"));
}

test "a report without the upstream revision is not uploadable" {
    var t = try testPackage(testing.allocator);
    defer t.pkg.deinit();
    defer t.manifest_arena.deinit();
    const chunk = try t.pkg.chunkIndex(".");
    const r1 = try reportJson(testing.allocator, result_b);
    defer testing.allocator.free(r1);
    const r2 = try std.mem.replaceOwned(u8, testing.allocator, r1, "afe89a5df4dcc7c6bcb317b07d6eee31a383c466", "");
    defer testing.allocator.free(r2);
    try t.pkg.addReport(r2, chunk, 1);
    try testing.expectError(error.RunInfoRevisionNotAFullSha, t.pkg.finalRunInfo("93049ebc2"));
}

test "chunks round-trip through gzip and pass the check; the check catches duplicates and Crane tests" {
    var t = try testPackage(testing.allocator);
    defer t.pkg.deinit();
    defer t.manifest_arena.deinit();
    const chunk = try t.pkg.chunkIndex(".");
    const report = try reportJson(testing.allocator, result_a_window ++ "," ++ result_a_worker ++ "," ++ result_b);
    defer testing.allocator.free(report);
    try t.pkg.addReport(report, chunk, 1);
    const ri = try t.pkg.finalRunInfo("93049ebc2aaaa");
    // A limit smaller than one result: one result per chunk.
    const chunks = try t.pkg.renderChunks(ri, 10);
    try testing.expectEqual(@as(usize, 3), chunks.len);

    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var round: std.ArrayList([]const u8) = .empty;
    for (chunks) |c| {
        const gz = try gzip(a, c);
        try round.append(a, try gunzip(a, gz));
        try testing.expectEqualStrings(c, round.items[round.items.len - 1]);
    }
    const res = try checkChunks(a, round.items);
    try testing.expectEqual(@as(usize, 0), res.problems.items.len);
    try testing.expectEqual(@as(usize, 3), res.results);

    // The same chunk twice: every one of its tests is a duplicate.
    const dup = try checkChunks(a, &.{ round.items[0], round.items[0] });
    try testing.expectEqual(@as(usize, 1), dup.problems.items.len);

    const with_crane = try std.mem.replaceOwned(u8, a, round.items[0], "/url/a.any.html", "/crane/a.html");
    const cr = try checkChunks(a, &.{with_crane});
    try testing.expectEqual(@as(usize, 1), cr.problems.items.len);

    // And the browser_version rule: a chunk whose version names no commit.
    const no_commit = try std.mem.replaceOwned(u8, a, round.items[0], "0.1.0-dev+93049ebc2", "0.1.0-dev");
    const nc = try checkChunks(a, &.{no_commit});
    try testing.expectEqual(@as(usize, 1), nc.problems.items.len);
}
