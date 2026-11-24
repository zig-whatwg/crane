//! The MCP differential suite (lane mcp1; design tmp/plans/mcp1-design.md
//! 8): the same tool calls to two MCP servers - Google's chrome-devtools-mcp
//! (pinned v1.13.0, under Node, driving Chrome for Testing) and Crane's own
//! (`repl --mcp`) - over stdio, each case on fresh servers, and their answers
//! compared after one normalisation (the fixture server's origin). The
//! measure of roadmap cdp-mcp: a tool is done when its cases are equal. Node
//! runs only Google's server, on the test side (main's answer Q2, 12:52 PM
//! ET 2026-11-23); nothing of it ships.
//!
//!   mcp_diff check --cases tools/mcp_diff/cases.json
//!   mcp_diff run --cases tools/mcp_diff/cases.json --fixtures tools/mcp_diff/fixtures
//!       --crane zig-out/bin/repl --node <node> --chrome-mcp <its bin .js> --chrome <Chrome for Testing>
//!       --out tmp/mcp-diff [--only <case name prefix>]
//!
//! Output: <out>/report.md (per case equal / differs, each differing call's
//! two answers) and <out>/results.json; each server's stderr in <out>/logs.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const client = @import("client.zig");
const fw_server = @import("fw_server");

const usage =
    \\usage: mcp_diff check --cases <cases.json>
    \\       mcp_diff run --cases <cases.json> --fixtures <dir> --crane <repl> --node <node>
    \\                    --chrome-mcp <chrome-devtools-mcp bin .js> --chrome <chrome> --out <dir> [--only <prefix>]
    \\
;

/// One tool call of a case; `sleep_ms` instead of a tool lets the page run
/// (a timer's dialog) between two calls.
pub const Call = struct {
    tool: []const u8 = "",
    /// The arguments; "{fixture}" in a string is the fixture server's origin.
    args: std.json.Value = .null,
    sleep_ms: u32 = 0,
};

pub const Case = struct {
    name: []const u8,
    /// What it measures (the report's line).
    about: []const u8 = "",
    calls: []const Call,
};

/// A call whose answers are known to differ, and why (main, 2:24 PM ET
/// 2026-11-23: a deferred feature's "not supported yet" is listed here).
pub const Expected = struct {
    case: []const u8,
    /// The tool call's number in its case, from 1 (sleeps not counted).
    call: u32,
    reason: []const u8,
};

pub const Cases = struct {
    cases: []const Case,
    expected: []const Expected = &.{},
};

fn expectedFor(cases: Cases, case: []const u8, call: usize) ?Expected {
    for (cases.expected) |e| if (e.call == call and std.mem.eql(u8, e.case, case)) return e;
    return null;
}

/// How long one call may take (Google's server starts Chrome on its first).
const call_timeout_ms = 90_000;

pub fn parseCases(arena: Allocator, text: []const u8) !Cases {
    return std.json.parseFromSliceLeaky(Cases, arena, text, .{ .ignore_unknown_fields = false });
}

/// The cases file's own checks: names unique and non-empty, every call a
/// tool or a sleep, arguments an object.
pub fn checkCases(cases: Cases) ![]const u8 {
    for (cases.cases, 0..) |c, i| {
        if (c.name.len == 0) return "a case has no name";
        for (cases.cases[0..i]) |other| if (std.mem.eql(u8, other.name, c.name)) return "two cases share a name";
        if (c.calls.len == 0) return "a case has no calls";
        for (c.calls) |call| {
            if (call.tool.len == 0 and call.sleep_ms == 0) return "a call names no tool and no sleep";
            if (call.tool.len != 0 and call.args != .object and call.args != .null) return "a call's args are not an object";
        }
    }
    for (cases.expected) |e| {
        const case = for (cases.cases) |c| {
            if (std.mem.eql(u8, c.name, e.case)) break c;
        } else return "an expected difference names no case";
        var tools: u32 = 0;
        for (case.calls) |call| {
            if (call.tool.len != 0) tools += 1;
        }
        if (e.call == 0 or e.call > tools) return "an expected difference names no call of its case";
        if (e.reason.len == 0) return "an expected difference gives no reason";
    }
    return "";
}

/// The arguments' JSON with "{fixture}" replaced by `origin`.
pub fn argsJson(arena: Allocator, args: std.json.Value, origin: []const u8) ![]const u8 {
    const text = if (args == .null) "{}" else try std.json.Stringify.valueAlloc(arena, args, .{});
    return std.mem.replaceOwned(u8, arena, text, "{fixture}", origin);
}

/// The answer as compared: the fixture server's origin as "{fixture}".
pub fn normalize(arena: Allocator, text: []const u8, origin: []const u8) ![]const u8 {
    return std.mem.replaceOwned(u8, arena, text, origin, "{fixture}");
}

const Side = enum { chrome, crane };

const Outcome = struct {
    answers: []client.Answer,
    /// Why the case could not finish on this side.
    failure: ?[]const u8 = null,
};

fn runSide(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8, log_path: []const u8, case: Case, origin: []const u8) Outcome {
    var answers: std.ArrayList(client.Answer) = .empty;
    const server = client.Server.start(gpa, io, argv, log_path) catch |err| {
        return .{ .answers = &.{}, .failure = std.fmt.allocPrint(arena, "could not start: {t}", .{err}) catch "could not start" };
    };
    defer server.stop();
    _ = server.request(arena, "initialize", "{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{},\"clientInfo\":{\"name\":\"crane-mcp-diff\",\"version\":\"1\"}}", call_timeout_ms) catch |err| {
        return .{ .answers = &.{}, .failure = std.fmt.allocPrint(arena, "initialize: {t}", .{err}) catch "initialize failed" };
    };
    server.notify(arena, "notifications/initialized", null) catch {};
    for (case.calls) |call| {
        if (call.tool.len == 0) {
            Io.sleep(io, .fromMilliseconds(call.sleep_ms), .awake) catch {};
            continue;
        }
        const args = argsJson(arena, call.args, origin) catch return .{ .answers = answers.items, .failure = "out of memory" };
        const params = std.fmt.allocPrint(arena, "{{\"name\":{f},\"arguments\":{s}}}", .{ std.json.fmt(call.tool, .{}), args }) catch return .{ .answers = answers.items, .failure = "out of memory" };
        const message = server.request(arena, "tools/call", params, call_timeout_ms) catch |err| {
            return .{ .answers = answers.items, .failure = std.fmt.allocPrint(arena, "{s}: {t}", .{ call.tool, err }) catch "call failed" };
        };
        var answer = client.answerOf(arena, message) catch return .{ .answers = answers.items, .failure = "unreadable answer" };
        answer.text = normalize(arena, answer.text, origin) catch answer.text;
        answers.append(arena, answer) catch return .{ .answers = answers.items, .failure = "out of memory" };
    }
    return .{ .answers = answers.items };
}

const Options = struct {
    cases: []const u8,
    fixtures: []const u8,
    crane: []const u8,
    node: []const u8,
    chrome_mcp: []const u8,
    chrome: []const u8,
    out: []const u8,
    only: ?[]const u8,
};

fn optionValue(argv: []const []const u8, name: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i + 1 < argv.len) : (i += 1) if (std.mem.eql(u8, argv[i], name)) return argv[i + 1];
    return null;
}

fn need(argv: []const []const u8, name: []const u8) []const u8 {
    return optionValue(argv, name) orelse {
        std.debug.print("mcp_diff: {s} is required\n{s}", .{ name, usage });
        std.process.exit(2);
    };
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const gpa = init.gpa;
    const argv = try init.minimal.args.toSlice(arena);
    if (argv.len < 2) {
        std.debug.print("{s}", .{usage});
        std.process.exit(2);
    }
    const rest = argv[2..];
    const cases_path = need(rest, "--cases");
    const cases_text = try Io.Dir.cwd().readFileAlloc(io, cases_path, arena, .limited(16 << 20));
    const cases = try parseCases(arena, cases_text);
    const problem = try checkCases(cases);
    if (problem.len != 0) {
        std.debug.print("mcp_diff: {s}: {s}\n", .{ cases_path, problem });
        std.process.exit(1);
    }
    if (std.mem.eql(u8, argv[1], "check")) {
        std.debug.print("mcp_diff: {d} cases OK\n", .{cases.cases.len});
        return;
    }
    if (!std.mem.eql(u8, argv[1], "run")) {
        std.debug.print("{s}", .{usage});
        std.process.exit(2);
    }
    const options: Options = .{
        .cases = cases_path,
        .fixtures = need(rest, "--fixtures"),
        .crane = need(rest, "--crane"),
        .node = need(rest, "--node"),
        .chrome_mcp = need(rest, "--chrome-mcp"),
        .chrome = need(rest, "--chrome"),
        .out = need(rest, "--out"),
        .only = optionValue(rest, "--only"),
    };
    try Io.Dir.cwd().createDirPath(io, try std.fmt.allocPrint(arena, "{s}/logs", .{options.out}));
    const fixtures = try fw_server.Server.start(gpa, io, .{ .root = options.fixtures });
    defer fixtures.stop();
    const origin = try std.fmt.allocPrint(arena, "http://127.0.0.1:{d}", .{fixtures.port()});

    const chrome_argv = [_][]const u8{ options.node, options.chrome_mcp, "--executablePath", options.chrome, "--headless", "--isolated", "--no-usage-statistics", "--no-performance-crux" };
    const crane_argv = [_][]const u8{ options.crane, "--mcp" };

    var report: Io.Writer.Allocating = .init(arena);
    const w = &report.writer;
    var results: Io.Writer.Allocating = .init(arena);
    const jw = &results.writer;
    try jw.writeAll("{\"cases\":[");
    var equal_cases: usize = 0;
    var expected_cases: usize = 0;
    var ran: usize = 0;
    var case_lines: std.ArrayList([]const u8) = .empty;
    for (cases.cases) |case| {
        if (options.only) |prefix| if (!std.mem.startsWith(u8, case.name, prefix)) continue;
        const slug = try slugOf(arena, case.name);
        const chrome = runSide(gpa, arena, io, &chrome_argv, try std.fmt.allocPrint(arena, "{s}/logs/{s}.chrome.log", .{ options.out, slug }), case, origin);
        const crane = runSide(gpa, arena, io, &crane_argv, try std.fmt.allocPrint(arena, "{s}/logs/{s}.crane.log", .{ options.out, slug }), case, origin);
        const equal = chrome.failure == null and crane.failure == null and sameAnswers(chrome.answers, crane.answers);
        const only_expected = !equal and chrome.failure == null and crane.failure == null and differsOnlyWhereExpected(cases, case.name, chrome.answers, crane.answers);
        if (equal) equal_cases += 1;
        if (only_expected) expected_cases += 1;
        if (ran != 0) try jw.writeAll(",");
        ran += 1;
        try jw.print("{{\"name\":{f},\"equal\":{},\"onlyExpectedDifferences\":{}", .{ std.json.fmt(case.name, .{}), equal, only_expected });
        try writeSideJson(jw, "chrome", chrome);
        try writeSideJson(jw, "crane", crane);
        try jw.writeAll("}");
        try case_lines.append(arena, try caseSection(arena, cases, case, chrome, crane, equal, only_expected));
        std.debug.print("mcp_diff: {s}: {s}\n", .{ case.name, if (equal) "equal" else if (only_expected) "differs where expected" else "DIFFERS" });
    }
    try jw.writeAll("]}\n");
    try w.print("# MCP differential suite\n\nchrome-devtools-mcp v1.13.0 (Chrome for Testing) against Crane's `repl --mcp`, the same calls on fresh servers per case; answers compared with the fixture origin as `{{fixture}}`.\n\n**{d} of {d} cases equal; {d} more differ only where expected.**\n\n", .{ equal_cases, ran, expected_cases });
    if (cases.expected.len > 0) {
        try w.writeAll("## Expected differences\n\n");
        for (cases.expected) |e| try w.print("- {s}, call {d}: {s}\n", .{ e.case, e.call, e.reason });
        try w.writeAll("\n");
    }
    for (case_lines.items) |section| try w.writeAll(section);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/report.md", .{options.out}), .data = report.written() });
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/results.json", .{options.out}), .data = results.written() });
    std.debug.print("mcp_diff: {d} of {d} cases equal; {s}/report.md\n", .{ equal_cases, ran, options.out });
}

fn sameAnswer(x: client.Answer, y: client.Answer) bool {
    return x.is_error == y.is_error and x.images == y.images and std.mem.eql(u8, x.text, y.text);
}

/// Every call that differs is listed as expected.
fn differsOnlyWhereExpected(cases: Cases, case: []const u8, a: []const client.Answer, b: []const client.Answer) bool {
    if (a.len != b.len) return false;
    for (a, b, 0..) |x, y, i| {
        if (!sameAnswer(x, y) and expectedFor(cases, case, i + 1) == null) return false;
    }
    return true;
}

fn sameAnswers(a: []const client.Answer, b: []const client.Answer) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (x.is_error != y.is_error or x.images != y.images or !std.mem.eql(u8, x.text, y.text)) return false;
    }
    return true;
}

fn writeSideJson(w: *Io.Writer, name: []const u8, outcome: Outcome) !void {
    try w.print(",\"{s}\":{{\"answers\":[", .{name});
    for (outcome.answers, 0..) |a, i| {
        if (i != 0) try w.writeAll(",");
        try w.print("{{\"text\":{f},\"isError\":{},\"images\":{d}}}", .{ std.json.fmt(a.text, .{}), a.is_error, a.images });
    }
    try w.writeAll("]");
    if (outcome.failure) |f| try w.print(",\"failure\":{f}", .{std.json.fmt(f, .{})});
    try w.writeAll("}");
}

fn caseSection(arena: Allocator, cases: Cases, case: Case, chrome: Outcome, crane: Outcome, equal: bool, only_expected: bool) ![]const u8 {
    var out: Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try w.print("## {s} - {s}\n\n", .{ case.name, if (equal) "equal" else if (only_expected) "differs where expected" else "differs" });
    if (case.about.len != 0) try w.print("{s}\n\n", .{case.about});
    if (chrome.failure) |f| try w.print("Chrome's side did not finish: {s}\n\n", .{f});
    if (crane.failure) |f| try w.print("Crane's side did not finish: {s}\n\n", .{f});
    if (equal) return out.written();
    var index: usize = 0;
    for (case.calls) |call| {
        if (call.tool.len == 0) continue;
        defer index += 1;
        const a: ?client.Answer = if (index < chrome.answers.len) chrome.answers[index] else null;
        const b: ?client.Answer = if (index < crane.answers.len) crane.answers[index] else null;
        if (a != null and b != null and a.?.is_error == b.?.is_error and std.mem.eql(u8, a.?.text, b.?.text)) continue;
        const why = if (expectedFor(cases, case.name, index + 1)) |e| try std.fmt.allocPrint(arena, " (expected: {s})", .{e.reason}) else "";
        try w.print("### call {d}: {s} {s}{s}\n\nChrome{s}:\n\n```\n{s}\n```\n\nCrane{s}:\n\n```\n{s}\n```\n\n", .{
            index + 1,
            call.tool,
            try std.json.Stringify.valueAlloc(arena, call.args, .{}),
            why,
            if (a != null and a.?.is_error) " (isError)" else "",
            if (a) |x| x.text else "(none)",
            if (b != null and b.?.is_error) " (isError)" else "",
            if (b) |x| x.text else "(none)",
        });
    }
    return out.written();
}

fn slugOf(arena: Allocator, name: []const u8) ![]const u8 {
    const out = try arena.dupe(u8, name);
    for (out) |*c| if (!std.ascii.isAlphanumeric(c.*)) {
        c.* = '-';
    };
    return out;
}

test "cases: parsed, checked, their arguments made with the fixture origin and answers normalised back" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cases = try parseCases(arena,
        \\{"cases":[{"name":"a","calls":[{"tool":"navigate_page","args":{"pageId":1,"url":"{fixture}/x.html"}},{"sleep_ms":10}]}]}
    );
    try std.testing.expectEqualStrings("", try checkCases(cases));
    try std.testing.expectEqualStrings("{\"pageId\":1,\"url\":\"http://127.0.0.1:9/x.html\"}", try argsJson(arena, cases.cases[0].calls[0].args, "http://127.0.0.1:9"));
    try std.testing.expectEqualStrings("Successfully navigated to {fixture}/x.html.", try normalize(arena, "Successfully navigated to http://127.0.0.1:9/x.html.", "http://127.0.0.1:9"));
    const twice = try parseCases(arena,
        \\{"cases":[{"name":"a","calls":[{"tool":"list_pages"}]},{"name":"a","calls":[{"tool":"list_pages"}]}]}
    );
    try std.testing.expectEqualStrings("two cases share a name", try checkCases(twice));
}

test "the repository's cases file is well formed" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const cases = try parseCases(arena_state.allocator(), @embedFile("cases.json"));
    try std.testing.expectEqualStrings("", try checkCases(cases));
}

test {
    _ = client;
}
