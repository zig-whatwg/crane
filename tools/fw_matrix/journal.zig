//! The framework matrix's journal, `crane-fw/1`: one JSON line per test of
//! a run and one per page, the only thing `fw_matrix run` writes and the only
//! thing the report reads (tmp/plans/framework-matrix-plan.md, section 4).
//!
//! `TestRecord` and `PageRecord` ARE the format: their field names, order and
//! types are what a line holds, and std.json parses a line into one of them
//! strictly - an unknown field, a missing required one or a value of the
//! wrong type is an error, never a silent default (perf_bench's journal.zig
//! is the model). `validate` checks what the types cannot say. The tests at
//! the end pin each kind of line byte for byte; changing the format means
//! changing `format_name` and those tests together.
//!
//! A page record carries the framework's OWN count of the tests it ran,
//! read from its summary display (QUnit "N tests completed in ...", Mocha's
//! stats line and its grep total) independently of the per-test list the
//! test records come from; `checkPage` compares the two.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const format_name = "crane-fw/1";

/// What happened to a test.
pub const Status = enum {
    /// It ran and the framework reported it passed.
    PASS,
    /// It ran and the framework reported it failed (`message`: the first
    /// failing assertion).
    FAIL,
    /// It was due to run, and the page ended its time before the framework
    /// reported it.
    TIMEOUT,
    /// It was due to run, and the console ended before the framework
    /// reported it.
    CRASH,
    /// It did not run: `not_run` says why.
    NOTRUN,

    /// Counted in "errored" on the matrix: due to run, never reported.
    pub fn errored(s: Status) bool {
        return s == .TIMEOUT or s == .CRASH;
    }
};

/// Why a test did not run. The first four are ours (an exclusion list
/// entry, each with its reason); the last is the project's own skip.
pub const NotRun = enum {
    /// Its assertion needs a layout box or pixels: Crane draws nothing
    /// (ruling R7; the plan's section 3).
    rendering,
    /// It needs the project's own test server (jQuery's mock.php actions;
    /// ruling R4: not built yet).
    needs_server,
    /// It needs a file the project's Node build writes (jQuery's babel-
    /// transpiled data file).
    needs_node_build,
    /// The project runs it only through its Node test runner (htmx's
    /// web-test-runner-only files; ruling R5).
    node_runner_only,
    /// The project skips it itself (QUnit.skip, Mocha's pending).
    project_skip,

    pub fn label(k: NotRun) []const u8 {
        return switch (k) {
            .rendering => "rendering",
            .needs_server => "needs the project's test server",
            .needs_node_build => "needs the project's Node build",
            .node_runner_only => "runs only through the project's Node test runner",
            .project_skip => "skipped by the project",
        };
    }
};

/// What a suite is: the project's own browser suite, or Crane's in-page port
/// of a shared app spec run against the framework's prebuilt app (the user,
/// 2026-11-11 09:57 ET: "Yes, TodoMVC" for React, Vue, Svelte and Angular).
/// Every record says which, so a reader never takes our port for the
/// project's own suite.
pub const SuiteKind = enum {
    project,
    todomvc_port,

    pub fn label(k: SuiteKind) []const u8 {
        return switch (k) {
            .project => "the project's own browser suite",
            // The user's words for these rows (2026-11-11).
            .todomvc_port => "TodoMVC; Crane's port of the app spec; the project's own suite is not runnable without Node",
        };
    }
};

/// One test of one page.
pub const TestRecord = struct {
    format: []const u8 = format_name,
    record: []const u8 = "test",
    /// The run's label (`fw_matrix run --label`).
    label: []const u8,
    /// The WPT generation whose console ran it; null for a lane's run.
    generation: ?u32 = null,
    crane_commit: []const u8,
    console_sha256: []const u8,
    /// The matrix row: the framework ("jquery").
    framework: []const u8,
    /// The framework's version as the suite runs it.
    version: []const u8,
    /// The manifest's suite id ("jquery-qunit").
    suite: []const u8,
    suite_kind: SuiteKind,
    /// The sha256 of the suite's source tarball (the manifest's).
    source_sha256: []const u8,
    /// The page's id in the manifest (jQuery: its module; htmx: "test").
    page: []const u8,
    /// QUnit: the test's module. Mocha: its suite path, joined by " > ".
    module: []const u8,
    name: []const u8,
    /// The name the framework's own filter matches: QUnit
    /// "<module>: <name>", Mocha the test's full title.
    id: []const u8,
    status: Status,
    not_run: ?NotRun = null,
    /// Why, for an exclusion of ours (its list's `why`).
    reason: ?[]const u8 = null,
    assertions_passed: ?u32 = null,
    assertions_total: ?u32 = null,
    /// FAIL: the first failing assertion as the framework printed it.
    message: ?[]const u8 = null,
    duration_ms: ?u64 = null,
};

pub const PageStatus = enum {
    /// The framework reported its run's end and its counts agree.
    OK,
    /// The page did not reach its end in its time.
    TIMEOUT,
    /// The console ended abnormally.
    CRASH,
    /// No report could be read, or the framework's own count disagrees with
    /// the tests read, or an exclusion names a test the page does not have.
    ERROR,
};

/// A resource the page loaded from outside the harness's server (ruling
/// R6): its URL as the page's resource timing lists it, and the sha256 the
/// harness's own fetch of that URL verified before the run (null when the
/// manifest pins none).
pub const Loaded = struct {
    url: []const u8,
    sha256: ?[]const u8 = null,
};

/// One page of a run.
pub const PageRecord = struct {
    format: []const u8 = format_name,
    record: []const u8 = "page",
    label: []const u8,
    generation: ?u32 = null,
    crane_commit: []const u8,
    console_sha256: []const u8,
    framework: []const u8,
    version: []const u8,
    suite: []const u8,
    suite_kind: SuiteKind,
    source_sha256: []const u8,
    page: []const u8,
    /// The URL the console opened (with the exclusion filter).
    url: []const u8,
    status: PageStatus,
    wall_ms: u64,
    /// The framework's own count of tests it ran (null when unread).
    reported_total: ?u32 = null,
    reported_failed: ?u32 = null,
    /// Test records written for the page with status PASS or FAIL.
    ran: u32,
    /// Test records written for the page, all statuses.
    records: u32,
    /// How the console ended ("exited with code 0", ...).
    exit: []const u8,
    /// Page errors the console printed (uncaught exceptions, unhandled
    /// rejections, the framework's global failures), at most `max_errors`.
    console_errors: []const []const u8 = &.{},
    loaded: []const Loaded = &.{},
    /// ERROR/TIMEOUT/CRASH: what went wrong.
    message: ?[]const u8 = null,
};

pub const max_errors = 20;

pub const ValidationError = error{ BadFormat, BadRecordKind, BadSha256, NotRunWithoutKind, KindWithoutNotRun, MissingMessage, EmptyName };

pub fn isSha256(s: []const u8) bool {
    if (s.len != 64) return false;
    for (s) |c| if (!std.ascii.isDigit(c) and !(c >= 'a' and c <= 'f')) return false;
    return true;
}

pub fn validateTest(r: TestRecord) ValidationError!void {
    if (!std.mem.eql(u8, r.format, format_name)) return error.BadFormat;
    if (!std.mem.eql(u8, r.record, "test")) return error.BadRecordKind;
    if (!isSha256(r.console_sha256) or !isSha256(r.source_sha256)) return error.BadSha256;
    if (r.id.len == 0) return error.EmptyName;
    if (r.status == .NOTRUN and r.not_run == null) return error.NotRunWithoutKind;
    if (r.status != .NOTRUN and r.not_run != null) return error.KindWithoutNotRun;
    if (r.status == .FAIL and r.message == null) return error.MissingMessage;
}

pub fn validatePage(r: PageRecord) ValidationError!void {
    if (!std.mem.eql(u8, r.format, format_name)) return error.BadFormat;
    if (!std.mem.eql(u8, r.record, "page")) return error.BadRecordKind;
    if (!isSha256(r.console_sha256) or !isSha256(r.source_sha256)) return error.BadSha256;
    if (r.status != .OK and r.message == null) return error.MissingMessage;
}

pub const Line = union(enum) {
    test_record: TestRecord,
    page_record: PageRecord,
};

pub const ParseError = std.json.ParseError(std.json.Scanner) || ValidationError;

/// One line, strictly. Which record it is comes from its `record` field,
/// read first; the line is then parsed into that type with no unknown field
/// allowed.
pub fn parseLine(arena: Allocator, line: []const u8) ParseError!Line {
    const Head = struct { record: []const u8 };
    const head = try std.json.parseFromSliceLeaky(Head, arena, line, .{ .ignore_unknown_fields = true });
    if (std.mem.eql(u8, head.record, "test")) {
        const r = try std.json.parseFromSliceLeaky(TestRecord, arena, line, .{});
        try validateTest(r);
        return .{ .test_record = r };
    }
    if (std.mem.eql(u8, head.record, "page")) {
        const r = try std.json.parseFromSliceLeaky(PageRecord, arena, line, .{});
        try validatePage(r);
        return .{ .page_record = r };
    }
    return error.BadRecordKind;
}

pub const Failure = struct {
    line: usize = 0,
    err: anyerror = error.None,
};

pub const Journal = struct {
    tests: []const TestRecord,
    pages: []const PageRecord,
};

/// Every record of a journal (blank lines skipped). On a bad line, `failure`
/// says which and why.
pub fn parseJournal(arena: Allocator, bytes: []const u8, failure: *Failure) !Journal {
    var tests: std.ArrayList(TestRecord) = .empty;
    var pages: std.ArrayList(PageRecord) = .empty;
    var it = std.mem.splitScalar(u8, bytes, '\n');
    var n: usize = 0;
    while (it.next()) |raw| {
        n += 1;
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;
        const l = parseLine(arena, line) catch |err| {
            failure.* = .{ .line = n, .err = err };
            return err;
        };
        switch (l) {
            .test_record => |t| try tests.append(arena, t),
            .page_record => |p| try pages.append(arena, p),
        }
    }
    return .{ .tests = tests.items, .pages = pages.items };
}

pub fn writeTest(w: *Io.Writer, r: TestRecord) Io.Writer.Error!void {
    try std.json.Stringify.value(r, .{ .emit_null_optional_fields = false }, w);
    try w.writeByte('\n');
}

pub fn writePage(w: *Io.Writer, r: PageRecord) Io.Writer.Error!void {
    try std.json.Stringify.value(r, .{ .emit_null_optional_fields = false }, w);
    try w.writeByte('\n');
}

/// The counts of one page's test records.
pub const Counts = struct {
    pass: u32 = 0,
    fail: u32 = 0,
    timeout: u32 = 0,
    crash: u32 = 0,
    rendering: u32 = 0,
    not_run: u32 = 0,
    project_skip: u32 = 0,

    pub fn add(c: *Counts, r: TestRecord) void {
        switch (r.status) {
            .PASS => c.pass += 1,
            .FAIL => c.fail += 1,
            .TIMEOUT => c.timeout += 1,
            .CRASH => c.crash += 1,
            .NOTRUN => switch (r.not_run.?) {
                .rendering => c.rendering += 1,
                .project_skip => c.project_skip += 1,
                else => c.not_run += 1,
            },
        }
    }

    pub fn ran(c: Counts) u32 {
        return c.pass + c.fail;
    }

    pub fn errored(c: Counts) u32 {
        return c.timeout + c.crash;
    }

    pub fn merge(c: *Counts, o: Counts) void {
        inline for (comptime std.meta.fieldNames(Counts)) |name| @field(c, name) += @field(o, name);
    }
};

const testing = std.testing;
const sha_a_bytes: [64]u8 = @splat('a');
const sha_a = &sha_a_bytes;
const sha_b_bytes: [64]u8 = @splat('b');
const sha_b = &sha_b_bytes;

test "a test record: one line, byte for byte, nulls left out" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try writeTest(&out.writer, .{
        .label = "fw1-b2",
        .crane_commit = "eb188adf573",
        .console_sha256 = sha_a,
        .framework = "jquery",
        .version = "4.0.0",
        .suite = "s",
        .suite_kind = .project,
        .source_sha256 = sha_b,
        .page = "css",
        .module = "css",
        .name = "css(String, Object)",
        .id = "css: css(String, Object)",
        .status = .FAIL,
        .assertions_passed = 3,
        .assertions_total = 4,
        .message = "fill-opacity\nExpected: \"0.5\"",
        .duration_ms = 12,
    });
    try testing.expectEqualStrings(
        "{\"format\":\"crane-fw/1\",\"record\":\"test\",\"label\":\"fw1-b2\",\"crane_commit\":\"eb188adf573\",\"console_sha256\":\"" ++ sha_a ++
            "\",\"framework\":\"jquery\",\"version\":\"4.0.0\",\"suite\":\"s\",\"suite_kind\":\"project\",\"source_sha256\":\"" ++ sha_b ++
            "\",\"page\":\"css\",\"module\":\"css\",\"name\":\"css(String, Object)\",\"id\":\"css: css(String, Object)\",\"status\":\"FAIL\",\"assertions_passed\":3,\"assertions_total\":4,\"message\":\"fill-opacity\\nExpected: \\\"0.5\\\"\",\"duration_ms\":12}\n",
        out.written(),
    );
}

test "a not-run record names its kind and reason" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try writeTest(&out.writer, .{
        .label = "x",
        .generation = 217,
        .crane_commit = "c",
        .console_sha256 = sha_a,
        .framework = "htmx",
        .version = "4.0.1",
        .suite = "s",
        .suite_kind = .project,
        .source_sha256 = sha_b,
        .page = "test",
        .module = "hx-swap modifiers",
        .name = "scrollTarget:window scrolls the window",
        .id = "hx-swap modifiers scrollTarget:window scrolls the window",
        .status = .NOTRUN,
        .not_run = .rendering,
        .reason = "asserts window.scrollY: a layout box",
    });
    try testing.expectEqualStrings(
        "{\"format\":\"crane-fw/1\",\"record\":\"test\",\"label\":\"x\",\"generation\":217,\"crane_commit\":\"c\",\"console_sha256\":\"" ++ sha_a ++
            "\",\"framework\":\"htmx\",\"version\":\"4.0.1\",\"suite\":\"s\",\"suite_kind\":\"project\",\"source_sha256\":\"" ++ sha_b ++
            "\",\"page\":\"test\",\"module\":\"hx-swap modifiers\",\"name\":\"scrollTarget:window scrolls the window\",\"id\":\"hx-swap modifiers scrollTarget:window scrolls the window\",\"status\":\"NOTRUN\",\"not_run\":\"rendering\",\"reason\":\"asserts window.scrollY: a layout box\"}\n",
        out.written(),
    );
}

test "a page record: one line, byte for byte" {
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try writePage(&out.writer, .{
        .label = "x",
        .crane_commit = "c",
        .console_sha256 = sha_a,
        .framework = "htmx",
        .version = "4.0.1",
        .suite = "s",
        .suite_kind = .project,
        .source_sha256 = sha_b,
        .page = "test",
        .url = "http://127.0.0.1:1/test/test.html",
        .status = .OK,
        .wall_ms = 161000,
        .reported_total = 1790,
        .reported_failed = 12,
        .ran = 1786,
        .records = 1790,
        .exit = "exited with code 0",
        .loaded = &.{.{ .url = "https://unpkg.com/mocha@11.7.5/mocha.js", .sha256 = sha_a }},
    });
    try testing.expectEqualStrings(
        "{\"format\":\"crane-fw/1\",\"record\":\"page\",\"label\":\"x\",\"crane_commit\":\"c\",\"console_sha256\":\"" ++ sha_a ++
            "\",\"framework\":\"htmx\",\"version\":\"4.0.1\",\"suite\":\"s\",\"suite_kind\":\"project\",\"source_sha256\":\"" ++ sha_b ++
            "\",\"page\":\"test\",\"url\":\"http://127.0.0.1:1/test/test.html\",\"status\":\"OK\",\"wall_ms\":161000,\"reported_total\":1790,\"reported_failed\":12,\"ran\":1786,\"records\":1790,\"exit\":\"exited with code 0\",\"console_errors\":[],\"loaded\":[{\"url\":\"https://unpkg.com/mocha@11.7.5/mocha.js\",\"sha256\":\"" ++ sha_a ++ "\"}]}\n",
        out.written(),
    );
}

test "lines read back strictly: an unknown field, a wrong type or a missing kind fail" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const good = "{\"format\":\"crane-fw/1\",\"record\":\"test\",\"label\":\"x\",\"crane_commit\":\"c\",\"console_sha256\":\"" ++ sha_a ++
        "\",\"framework\":\"f\",\"version\":\"1\",\"suite\":\"s\",\"suite_kind\":\"project\",\"source_sha256\":\"" ++ sha_b ++ "\",\"page\":\"p\",\"module\":\"m\",\"name\":\"n\",\"id\":\"m: n\",\"status\":\"PASS\"}";
    const l = try parseLine(arena, good);
    try testing.expectEqual(Status.PASS, l.test_record.status);
    try testing.expectError(error.UnknownField, parseLine(arena, good[0 .. good.len - 1] ++ ",\"extra\":1}"));
    try testing.expectError(error.InvalidEnumTag, parseLine(arena, std.mem.replaceOwned(u8, arena, good, "PASS", "pass") catch unreachable));
    try testing.expectError(error.NotRunWithoutKind, parseLine(arena, std.mem.replaceOwned(u8, arena, good, "PASS", "NOTRUN") catch unreachable));
    try testing.expectError(error.MissingMessage, parseLine(arena, std.mem.replaceOwned(u8, arena, good, "PASS", "FAIL") catch unreachable));
    try testing.expectError(error.BadSha256, parseLine(arena, std.mem.replaceOwned(u8, arena, good, sha_a, "abc") catch unreachable));
    try testing.expectError(error.BadRecordKind, parseLine(arena, "{\"record\":\"other\"}"));
}

test "a journal: tests and pages apart; a bad line names its number" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var out: Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    const base: TestRecord = .{ .label = "x", .crane_commit = "c", .console_sha256 = sha_a, .framework = "f", .version = "1", .suite = "s", .suite_kind = .project, .source_sha256 = sha_b, .page = "p", .module = "m", .name = "n", .id = "m: n", .status = .PASS };
    try writeTest(&out.writer, base);
    var skipped = base;
    skipped.status = .NOTRUN;
    skipped.not_run = .needs_server;
    skipped.reason = "mock.php";
    try writeTest(&out.writer, skipped);
    try writePage(&out.writer, .{ .label = "x", .crane_commit = "c", .console_sha256 = sha_a, .framework = "f", .version = "1", .suite = "s", .suite_kind = .project, .source_sha256 = sha_b, .page = "p", .url = "u", .status = .OK, .wall_ms = 1, .ran = 1, .records = 2, .exit = "exited with code 0" });
    var failure: Failure = .{};
    const j = try parseJournal(arena, out.written(), &failure);
    try testing.expectEqual(@as(usize, 2), j.tests.len);
    try testing.expectEqual(@as(usize, 1), j.pages.len);
    var c: Counts = .{};
    for (j.tests) |t| c.add(t);
    try testing.expectEqual(@as(u32, 1), c.ran());
    try testing.expectEqual(@as(u32, 1), c.not_run);

    const bad = try std.fmt.allocPrint(arena, "{s}{{\"record\":\"test\"}}\n", .{out.written()});
    try testing.expectError(error.MissingField, parseJournal(arena, bad, &failure));
    try testing.expectEqual(@as(usize, 4), failure.line);
}
