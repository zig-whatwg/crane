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
//! Chrome's snapshots are compared with its user-agent shadow nodes set
//! apart (user_agent.zig): Crane has no user-agent shadow DOM.
//!
//! A case with `files` gives each server a directory of its own (the
//! fixtures' files/ copied in, "{files}" in arguments, normalised back in
//! answers) as its --filesystemRoot; with `client_roots`, the client
//! advertises roots and answers roots/list with that directory instead. Its
//! last compared answer is the directory afterwards - each file's path, mode
//! and bytes. The working directory, which a relative path resolves under,
//! reads "{cwd}".
//!
//! Output: <out>/report.md (per case equal / differs, each differing call's
//! two answers) and <out>/results.json; each server's stderr in <out>/logs.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const client = @import("client.zig");
const user_agent = @import("user_agent.zig");
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
    /// Instead of a tool call: tools/list, its answer the definitions of
    /// these tools in this order (null for one not listed) - how a case's
    /// flags shape the schemas both servers list (lane mcp3, audit M2).
    list_tools: []const []const u8 = &.{},
    /// "chrome": the call runs on Chrome's side only and its answer is not
    /// compared - how a case makes an input both sides then read (a heap
    /// snapshot Chrome takes, copied to Crane by `copy_to_crane`).
    side: []const u8 = "",

    /// Whether the call has an answer both sides compare (a tool call or a
    /// tools/list, on both sides).
    pub fn answered(self: Call) bool {
        return (self.tool.len != 0 or self.list_tools.len != 0) and self.side.len == 0;
    }
};

pub const Case = struct {
    name: []const u8,
    /// What it measures (the report's line).
    about: []const u8 = "",
    calls: []const Call,
    /// A directory per server, its --filesystemRoot ("{files}").
    files: bool = false,
    /// The directory reached through the client's MCP roots instead.
    client_roots: bool = false,
    /// Pass --memoryDebugging to both servers (enables heap analysis tools).
    memory_debugging: bool = false,
    /// Pass --categoryNetworkMocks to both servers.
    category_network_mocks: bool = false,
    /// Pass --categoryExperimentalThirdParty to both servers.
    category_experimental_third_party: bool = false,
    /// Pass --experimentalVision to both servers.
    experimental_vision: bool = false,
    /// Pass --slim to both servers.
    slim: bool = false,
    /// Fixture files (under --fixtures) copied into each server's `{files}` dir.
    copy_fixtures: []const []const u8 = &.{},
    /// More flags given to both servers, as chrome-devtools-mcp spells them
    /// ("--no-page-id-routing", "--maxNavigationSaved=2").
    flags: []const []const u8 = &.{},
    /// Files (in `{files}`) Chrome's side made that are copied to Crane's
    /// `{files}` after Chrome's side ran and before Crane's runs: both
    /// analyse the same input (audit M6: a heap snapshot of a real page).
    copy_to_crane: []const []const u8 = &.{},
};

pub const chrome_mcp_version = "1.13.0";

pub const ToolClass = enum {
    equal,
    expected_diff,
    differs,
    needs_renderer,
    chrome_only,
    not_tested,
    /// The engine feature the tool reads is not in Crane yet; the reason
    /// names the lane that builds it.
    not_implemented,

    pub fn word(self: ToolClass) []const u8 {
        return switch (self) {
            .equal => "equal",
            .expected_diff => "expected_diff",
            .differs => "differs",
            .needs_renderer => "needs_renderer",
            .chrome_only => "chrome_only",
            .not_tested => "not_tested",
            .not_implemented => "not_implemented",
        };
    }
};

pub const CatalogEntry = struct {
    name: []const u8,
    category: []const u8,
    /// Fixed classification for renderer-dependent or Chrome-product tools;
    /// null for web-platform tools judged by the differential cases.
    fixed: ?ToolClass = null,
    reason: []const u8 = "",
};

/// All 66 tools of chrome-devtools-mcp v1.13.0 (63 documented + 3 slim),
/// matching tmp/plans/mcp1-design-tools.md and §11 Q5.
pub const tool_catalog = [_]CatalogEntry{
    // Input (10)
    .{ .name = "click", .category = "input" },
    .{ .name = "drag", .category = "input" },
    .{ .name = "fill", .category = "input" },
    .{ .name = "fill_form", .category = "input" },
    .{ .name = "handle_dialog", .category = "input" },
    .{ .name = "hover", .category = "input" },
    .{ .name = "press_key", .category = "input" },
    .{ .name = "type_text", .category = "input" },
    .{ .name = "upload_file", .category = "input" },
    .{ .name = "click_at", .category = "input", .fixed = .needs_renderer, .reason = "Coordinate-based clicks require a renderer/layout engine to hit-test screen coordinates." },
    // Navigation (6)
    .{ .name = "close_page", .category = "navigation" },
    .{ .name = "list_pages", .category = "navigation" },
    .{ .name = "navigate_page", .category = "navigation" },
    .{ .name = "new_page", .category = "navigation" },
    .{ .name = "select_page", .category = "navigation" },
    .{ .name = "wait_for", .category = "navigation" },
    // Emulation (2)
    .{ .name = "emulate", .category = "emulation" },
    .{ .name = "resize_page", .category = "emulation" },
    // Performance (3)
    .{ .name = "performance_start_trace", .category = "performance", .fixed = .needs_renderer, .reason = "Performance traces require a rendering pipeline for frames, paint, LCP/CLS/INP, and trace screenshots." },
    .{ .name = "performance_stop_trace", .category = "performance", .fixed = .needs_renderer, .reason = "Performance traces require a rendering pipeline." },
    .{ .name = "performance_analyze_insight", .category = "performance", .fixed = .needs_renderer, .reason = "Performance trace insights require recorded renderer traces." },
    // Network (2)
    .{ .name = "get_network_request", .category = "network" },
    .{ .name = "list_network_requests", .category = "network" },
    // Network mocks (2)
    .{ .name = "mock_network", .category = "networkMocks" },
    .{ .name = "remove_network_mock", .category = "networkMocks" },
    // Debugging (10)
    .{ .name = "evaluate_script", .category = "debugging" },
    .{ .name = "get_console_message", .category = "debugging" },
    .{ .name = "get_css_styles", .category = "debugging" },
    .{ .name = "lighthouse_audit", .category = "debugging", .fixed = .chrome_only, .reason = "Google's Lighthouse bundle is a Chrome product, not a web platform specification." },
    .{ .name = "list_console_messages", .category = "debugging" },
    .{ .name = "screencast_start", .category = "debugging", .fixed = .needs_renderer, .reason = "Screencast recording requires a pixel renderer." },
    .{ .name = "screencast_stop", .category = "debugging", .fixed = .needs_renderer, .reason = "Screencast recording requires a pixel renderer." },
    .{ .name = "set_logpoints", .category = "debugging" },
    .{ .name = "take_screenshot", .category = "debugging", .fixed = .needs_renderer, .reason = "Screenshots require a pixel renderer." },
    .{ .name = "take_snapshot", .category = "debugging" },
    // Memory (14)
    .{ .name = "take_heapsnapshot", .category = "memory" },
    .{ .name = "get_heapsnapshot_summary", .category = "memory" },
    .{ .name = "get_heapsnapshot_details", .category = "memory" },
    .{ .name = "get_heapsnapshot_class_nodes", .category = "memory" },
    .{ .name = "get_heapsnapshot_retainers", .category = "memory" },
    .{ .name = "close_heapsnapshot", .category = "memory" },
    .{ .name = "get_heapsnapshot_retaining_paths", .category = "memory" },
    .{ .name = "get_heapsnapshot_edges", .category = "memory" },
    .{ .name = "get_heapsnapshot_dominators", .category = "memory" },
    .{ .name = "compare_heapsnapshots", .category = "memory" },
    .{ .name = "get_heapsnapshot_duplicate_strings", .category = "memory" },
    .{ .name = "get_heapsnapshot_object_details", .category = "memory" },
    .{ .name = "query_heapsnapshot_objects", .category = "memory" },
    .{ .name = "analyze_heapsnapshot_contexts", .category = "memory" },
    // Third-party developer tools (2)
    .{ .name = "list_3p_developer_tools", .category = "thirdParty" },
    .{ .name = "execute_3p_developer_tool", .category = "thirdParty" },
    // WebMCP (2)
    .{ .name = "list_webmcp_tools", .category = "webmcp", .fixed = .not_implemented, .reason = "Not implemented: reads what the page registers through document.modelContext (WebMCP; Chrome exposes it only behind --enable-features=WebMCP or its origin trial) over CDP WebMCP - both built by lane webmcp1 (main, 5:52 PM ET 2026-11-27)." },
    .{ .name = "execute_webmcp_tool", .category = "webmcp", .fixed = .not_implemented, .reason = "Not implemented: runs a page's document.modelContext tool through CDP WebMCP.invokeTool - lane webmcp1 (main, 5:52 PM ET 2026-11-27)." },
    // WebAuthn (1)
    .{ .name = "configure_webauthn", .category = "webauthn", .fixed = .not_implemented, .reason = "Not implemented: needs WebAuthn (navigator.credentials.create/get), a virtual authenticator and CDP WebAuthn - lane webauthn1 (main, 5:45 PM ET 2026-11-27)." },
    // Extensions (5) - Chrome product
    .{ .name = "install_extension", .category = "extensions", .fixed = .chrome_only, .reason = "Chrome's extension system has no web specification." },
    .{ .name = "list_extensions", .category = "extensions", .fixed = .chrome_only, .reason = "Chrome's extension system has no web specification." },
    .{ .name = "reload_extension", .category = "extensions", .fixed = .chrome_only, .reason = "Chrome's extension system has no web specification." },
    .{ .name = "trigger_extension_action", .category = "extensions", .fixed = .chrome_only, .reason = "Chrome's extension system has no web specification." },
    .{ .name = "uninstall_extension", .category = "extensions", .fixed = .chrome_only, .reason = "Chrome's extension system has no web specification." },
    // PWA (4) - Chrome product
    .{ .name = "get_os_app_state", .category = "pwa", .fixed = .chrome_only, .reason = "OS app installation (CDP PWA domain) is a Chrome product feature, not a web specification." },
    .{ .name = "install_pwa", .category = "pwa", .fixed = .chrome_only, .reason = "OS app installation (CDP PWA domain) is a Chrome product feature, not a web specification." },
    .{ .name = "launch_pwa", .category = "pwa", .fixed = .chrome_only, .reason = "OS app installation (CDP PWA domain) is a Chrome product feature, not a web specification." },
    .{ .name = "uninstall_pwa", .category = "pwa", .fixed = .chrome_only, .reason = "OS app installation (CDP PWA domain) is a Chrome product feature, not a web specification." },
    // Slim mode (3)
    .{ .name = "navigate", .category = "slim" },
    .{ .name = "evaluate", .category = "slim" },
    .{ .name = "screenshot", .category = "slim", .fixed = .needs_renderer, .reason = "Screenshots require a pixel renderer." },
};

pub const CaseRecord = struct {
    case: Case,
    chrome: Outcome,
    crane: Outcome,
    equal: bool,
    only_expected: bool,
};

pub const ToolSummaryRow = struct {
    name: []const u8,
    category: []const u8,
    status: ToolClass,
    cases: []const []const u8,
    reason: []const u8,
};

pub const SummaryCounts = struct {
    cases_total: usize = 0,
    cases_equal: usize = 0,
    cases_expected_diff: usize = 0,
    cases_differs: usize = 0,
    tools_total: usize = 0,
    tools_equal: usize = 0,
    tools_expected_diff: usize = 0,
    tools_differs: usize = 0,
    tools_needs_renderer: usize = 0,
    tools_chrome_only: usize = 0,
    tools_not_tested: usize = 0,
    tools_not_implemented: usize = 0,
};

pub fn classifyTools(arena: Allocator, cases: Cases, records: []const CaseRecord) !struct { summary: SummaryCounts, tools: []ToolSummaryRow } {
    var summary: SummaryCounts = .{ .cases_total = records.len, .tools_total = tool_catalog.len };
    for (records) |rec| {
        if (rec.equal) {
            summary.cases_equal += 1;
        } else if (rec.only_expected) {
            summary.cases_expected_diff += 1;
        } else {
            summary.cases_differs += 1;
        }
    }
    const rows = try arena.alloc(ToolSummaryRow, tool_catalog.len);
    for (tool_catalog, 0..) |entry, ti| {
        var matched_cases: std.ArrayList([]const u8) = .empty;
        var seen_any = false;
        var any_unexpected = false;
        var expected_reason: []const u8 = "";

        for (records) |rec| {
            var call_idx: usize = 0;
            var case_used = false;
            for (rec.case.calls) |c| {
                if (!c.answered()) continue;
                defer call_idx += 1;
                if (!std.mem.eql(u8, c.tool, entry.name)) continue;
                seen_any = true;
                if (!case_used) {
                    try matched_cases.append(arena, rec.case.name);
                    case_used = true;
                }
                if (rec.chrome.failure != null or rec.crane.failure != null) {
                    any_unexpected = true;
                    continue;
                }
                const a_opt: ?client.Answer = if (call_idx < rec.chrome.answers.len) rec.chrome.answers[call_idx] else null;
                const b_opt: ?client.Answer = if (call_idx < rec.crane.answers.len) rec.crane.answers[call_idx] else null;
                const call_equal = a_opt != null and b_opt != null and sameAnswer(a_opt.?, b_opt.?);
                if (!call_equal) {
                    if (expectedFor(cases, rec.case.name, call_idx + 1)) |exp| {
                        if (expected_reason.len == 0) expected_reason = exp.reason;
                    } else {
                        any_unexpected = true;
                    }
                }
            }
        }

        const status: ToolClass = if (entry.fixed) |fixed|
            fixed
        else if (!seen_any)
            .not_tested
        else if (any_unexpected)
            .differs
        else if (expected_reason.len != 0)
            .expected_diff
        else
            .equal;

        const reason = if (entry.fixed != null)
            entry.reason
        else if (status == .expected_diff)
            expected_reason
        else
            entry.reason;

        switch (status) {
            .equal => summary.tools_equal += 1,
            .expected_diff => summary.tools_expected_diff += 1,
            .differs => summary.tools_differs += 1,
            .needs_renderer => summary.tools_needs_renderer += 1,
            .chrome_only => summary.tools_chrome_only += 1,
            .not_tested => summary.tools_not_tested += 1,
            .not_implemented => summary.tools_not_implemented += 1,
        }
        rows[ti] = .{
            .name = entry.name,
            .category = entry.category,
            .status = status,
            .cases = matched_cases.items,
            .reason = reason,
        };
    }
    return .{ .summary = summary, .tools = rows };
}

pub fn writeResultsJson(w: *Io.Writer, summary: SummaryCounts, tools: []const ToolSummaryRow, records: []const CaseRecord) !void {
    try w.print(
        "{{\"version\":1,\"chromeMcpVersion\":{f},\"summary\":{{" ++
            "\"casesTotal\":{d},\"casesEqual\":{d},\"casesExpectedDiff\":{d},\"casesDiffers\":{d}," ++
            "\"toolsTotal\":{d},\"toolsEqual\":{d},\"toolsExpectedDiff\":{d},\"toolsDiffers\":{d}," ++
            "\"toolsNeedsRenderer\":{d},\"toolsChromeOnly\":{d},\"toolsNotTested\":{d},\"toolsNotImplemented\":{d}}},\"tools\":[",
        .{
            std.json.fmt(chrome_mcp_version, .{}),
            summary.cases_total,
            summary.cases_equal,
            summary.cases_expected_diff,
            summary.cases_differs,
            summary.tools_total,
            summary.tools_equal,
            summary.tools_expected_diff,
            summary.tools_differs,
            summary.tools_needs_renderer,
            summary.tools_chrome_only,
            summary.tools_not_tested,
            summary.tools_not_implemented,
        },
    );
    for (tools, 0..) |t, i| {
        if (i != 0) try w.writeAll(",");
        try w.print("{{\"name\":{f},\"category\":{f},\"status\":{f},\"cases\":[", .{
            std.json.fmt(t.name, .{}),
            std.json.fmt(t.category, .{}),
            std.json.fmt(t.status.word(), .{}),
        });
        for (t.cases, 0..) |c, ci| {
            if (ci != 0) try w.writeAll(",");
            try w.print("{f}", .{std.json.fmt(c, .{})});
        }
        try w.print("],\"reason\":{f}}}", .{std.json.fmt(t.reason, .{})});
    }
    try w.writeAll("],\"cases\":[");
    for (records, 0..) |rec, i| {
        if (i != 0) try w.writeAll(",");
        try w.print("{{\"name\":{f},\"about\":{f},\"equal\":{},\"onlyExpectedDifferences\":{}", .{
            std.json.fmt(rec.case.name, .{}),
            std.json.fmt(rec.case.about, .{}),
            rec.equal,
            rec.only_expected,
        });
        try writeSideJson(w, "chrome", rec.chrome);
        try writeSideJson(w, "crane", rec.crane);
        try w.writeAll("}");
    }
    try w.writeAll("]}\n");
}

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
            if (call.tool.len == 0 and call.list_tools.len == 0 and call.sleep_ms == 0) return "a call names no tool, no tools/list and no sleep";
            if (call.side.len != 0 and !std.mem.eql(u8, call.side, "chrome")) return "a call's side is not \"chrome\"";
            if (call.tool.len != 0 and call.args != .object and call.args != .null) return "a call's args are not an object";
        }
    }
    for (cases.expected) |e| {
        const case = for (cases.cases) |c| {
            if (std.mem.eql(u8, c.name, e.case)) break c;
        } else return "an expected difference names no case";
        var tools: u32 = 0;
        for (case.calls) |call| {
            if (call.answered()) tools += 1;
        }
        if (e.call == 0 or e.call > tools) return "an expected difference names no call of its case";
        if (e.reason.len == 0) return "an expected difference gives no reason";
    }
    return "";
}

/// What a side's arguments and answers name in their own way: the fixture
/// server's origin, the side's files directory, the working directory.
pub const Places = struct {
    origin: []const u8,
    files: ?[]const u8 = null,
    cwd: ?[]const u8 = null,
};

/// The arguments' JSON with "{fixture}" and "{files}" made the side's.
pub fn argsJson(arena: Allocator, args: std.json.Value, places: Places) ![]const u8 {
    const text = if (args == .null) "{}" else try std.json.Stringify.valueAlloc(arena, args, .{});
    const with_origin = try std.mem.replaceOwned(u8, arena, text, "{fixture}", places.origin);
    return if (places.files) |dir| std.mem.replaceOwned(u8, arena, with_origin, "{files}", dir) else with_origin;
}

/// The answer as compared: the side's places by their names - the files
/// directory before the working directory, which may hold it.
pub fn normalize(arena: Allocator, text: []const u8, places: Places) ![]const u8 {
    var out = text;
    if (places.files) |dir| out = try std.mem.replaceOwned(u8, arena, out, dir, "{files}");
    out = try std.mem.replaceOwned(u8, arena, out, places.origin, "{fixture}");
    if (places.cwd) |dir| out = try std.mem.replaceOwned(u8, arena, out, dir, "{cwd}");
    return out;
}

const Side = enum { chrome, crane };

const Outcome = struct {
    answers: []client.Answer,
    /// Why the case could not finish on this side.
    failure: ?[]const u8 = null,
};

/// Chrome's side's extra: its remote debugging port and the case's replay
/// of Google's numbering (user_agent.zig).
const ChromePage = struct {
    port: u16,
    replay: user_agent.Replay = .{},
};

fn runSide(gpa: Allocator, arena: Allocator, io: Io, argv: []const []const u8, log_path: []const u8, case: Case, places: Places, chrome_page: ?*ChromePage) Outcome {
    var answers: std.ArrayList(client.Answer) = .empty;
    const server = client.Server.start(gpa, io, argv, log_path) catch |err| {
        return .{ .answers = &.{}, .failure = std.fmt.allocPrint(arena, "could not start: {t}", .{err}) catch "could not start" };
    };
    defer server.stop();
    var capabilities: []const u8 = "{}";
    if (case.client_roots) if (places.files) |dir| {
        server.roots_json = std.fmt.allocPrint(arena, "[{{\"uri\":\"file://{s}\",\"name\":\"files\"}}]", .{dir}) catch return .{ .answers = &.{}, .failure = "out of memory" };
        capabilities = "{\"roots\":{\"listChanged\":true}}";
    };
    const initialize = std.fmt.allocPrint(arena, "{{\"protocolVersion\":\"2025-11-25\",\"capabilities\":{s},\"clientInfo\":{{\"name\":\"crane-mcp-diff\",\"version\":\"1\"}}}}", .{capabilities}) catch return .{ .answers = &.{}, .failure = "out of memory" };
    _ = server.request(arena, "initialize", initialize, call_timeout_ms) catch |err| {
        return .{ .answers = &.{}, .failure = std.fmt.allocPrint(arena, "initialize: {t}", .{err}) catch "initialize failed" };
    };
    server.notify(arena, "notifications/initialized", null) catch {};
    for (case.calls) |call| {
        if (call.list_tools.len != 0) {
            const message = server.request(arena, "tools/list", "{}", call_timeout_ms) catch |err| {
                return .{ .answers = answers.items, .failure = std.fmt.allocPrint(arena, "tools/list: {t}", .{err}) catch "tools/list failed" };
            };
            const text = listedDefinitions(arena, message, call.list_tools) catch "unreadable tools/list";
            answers.append(arena, .{ .text = normalize(arena, text, places) catch text, .is_error = false }) catch return .{ .answers = answers.items, .failure = "out of memory" };
            continue;
        }
        if (call.tool.len == 0) {
            Io.sleep(io, .fromMilliseconds(call.sleep_ms), .awake) catch {};
            continue;
        }
        // A one-side call: Chrome's alone, its answer not kept.
        const one_side = call.side.len != 0;
        if (one_side and chrome_page == null) continue;
        // A uid a call names is Crane's numbering: Chrome's for Chrome.
        const call_args = if (chrome_page) |c| c.replay.argsForChrome(arena, call.args) catch call.args else call.args;
        const args = argsJson(arena, call_args, places) catch return .{ .answers = answers.items, .failure = "out of memory" };
        const params = std.fmt.allocPrint(arena, "{{\"name\":{f},\"arguments\":{s}}}", .{ std.json.fmt(call.tool, .{}), args }) catch return .{ .answers = answers.items, .failure = "out of memory" };
        const message = server.request(arena, "tools/call", params, call_timeout_ms) catch |err| {
            return .{ .answers = answers.items, .failure = std.fmt.allocPrint(arena, "{s}: {t}", .{ call.tool, err }) catch "call failed" };
        };
        var answer = client.answerOf(arena, message) catch return .{ .answers = answers.items, .failure = "unreadable answer" };
        if (chrome_page) |c| if (user_agent.hasSnapshot(answer.text)) setApart(gpa, arena, io, c, call, &answer);
        answer.text = normalize(arena, answer.text, places) catch answer.text;
        if (answer.raw) |raw| answer.raw = normalize(arena, raw, places) catch raw;
        if (one_side) {
            if (answer.is_error) return .{ .answers = answers.items, .failure = std.fmt.allocPrint(arena, "{s} (Chrome's side only): {s}", .{ call.tool, answer.text }) catch "a one-side call failed" };
            continue;
        }
        answers.append(arena, answer) catch return .{ .answers = answers.items, .failure = "out of memory" };
    }
    if (places.files) |dir| {
        // What the calls left in the directory, compared as one more answer.
        const listing = filesListing(arena, io, dir) catch |err| return .{ .answers = answers.items, .failure = std.fmt.allocPrint(arena, "listing the files: {t}", .{err}) catch "listing failed" };
        answers.append(arena, .{ .text = normalize(arena, listing, places) catch listing, .is_error = false }) catch return .{ .answers = answers.items, .failure = "out of memory" };
    }
    return .{ .answers = answers.items };
}

/// A tools/list answer's definitions of `names`, in that order, as indented
/// JSON (null for a tool not listed).
fn listedDefinitions(arena: Allocator, message: std.json.Value, names: []const []const u8) ![]const u8 {
    const result = message.object.get("result") orelse return error.NoResult;
    const tools = result.object.get("tools") orelse return error.NoTools;
    var out: Io.Writer.Allocating = .init(arena);
    try out.writer.writeAll("[");
    for (names, 0..) |name, i| {
        if (i != 0) try out.writer.writeAll(",");
        const definition: std.json.Value = for (tools.array.items) |d| {
            if (d == .object) if (d.object.get("name")) |n| if (n == .string and std.mem.eql(u8, n.string, name)) break d;
        } else .null;
        try std.json.Stringify.value(definition, .{ .whitespace = .indent_1 }, &out.writer);
    }
    try out.writer.writeAll("]");
    return out.written();
}

/// Every regular file under `dir`, by path: "<path> <mode>" then its bytes.
fn filesListing(arena: Allocator, io: Io, dir_path: []const u8) ![]const u8 {
    const dir = try Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    var names: std.ArrayList([]const u8) = .empty;
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        try names.append(arena, try arena.dupe(u8, entry.path));
    }
    std.mem.sort([]const u8, names.items, {}, struct {
        fn less(_: void, x: []const u8, y: []const u8) bool {
            return std.mem.lessThan(u8, x, y);
        }
    }.less);
    var out: Io.Writer.Allocating = .init(arena);
    for (names.items) |name| {
        const st = try dir.statFile(io, name, .{});
        const mode = st.permissions.toMode() & 0o777;
        if (std.mem.endsWith(u8, name, ".heapsnapshot")) {
            const bytes = try dir.readFileAlloc(io, name, arena, .limited(512 << 20));
            const summary = summarizeHeapSnapshot(arena, bytes) catch "invalid heapsnapshot";
            try out.writer.print("{s} {o}\n{s}\n", .{ name, mode, summary });
            continue;
        }
        const bytes = try dir.readFileAlloc(io, name, arena, .limited(1 << 20));
        try out.writer.print("{s} {o}\n{s}\n", .{ name, mode, bytes });
    }
    return out.written();
}

/// Validate a V8 `.heapsnapshot` file's JSON structure and summarise its
/// invariants deterministically (live heap addresses and sizes differ across
/// Chrome and Crane).
fn summarizeHeapSnapshot(arena: Allocator, bytes: []const u8) ![]const u8 {
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, bytes, .{});
    if (parsed != .object) return error.InvalidSnapshot;
    const root = parsed.object;
    const snap = (root.get("snapshot") orelse return error.InvalidSnapshot);
    if (snap != .object) return error.InvalidSnapshot;
    const meta = (snap.object.get("meta") orelse return error.InvalidSnapshot);
    if (meta != .object) return error.InvalidSnapshot;
    const node_fields = (meta.object.get("node_fields") orelse return error.InvalidSnapshot);
    const node_types = (meta.object.get("node_types") orelse return error.InvalidSnapshot);
    const edge_fields = (meta.object.get("edge_fields") orelse return error.InvalidSnapshot);
    const edge_types = (meta.object.get("edge_types") orelse return error.InvalidSnapshot);
    if (node_fields != .array or node_types != .array or edge_fields != .array or edge_types != .array) return error.InvalidSnapshot;
    if (node_fields.array.items.len == 0 or edge_fields.array.items.len == 0) return error.InvalidSnapshot;
    const node_count_val = (snap.object.get("node_count") orelse return error.InvalidSnapshot);
    const edge_count_val = (snap.object.get("edge_count") orelse return error.InvalidSnapshot);
    if (node_count_val != .integer or edge_count_val != .integer) return error.InvalidSnapshot;
    if (node_count_val.integer <= 0 or edge_count_val.integer <= 0) return error.InvalidSnapshot;
    const node_count: usize = @intCast(node_count_val.integer);
    const edge_count: usize = @intCast(edge_count_val.integer);
    const nodes = (root.get("nodes") orelse return error.InvalidSnapshot);
    const edges = (root.get("edges") orelse return error.InvalidSnapshot);
    const strings = (root.get("strings") orelse return error.InvalidSnapshot);
    if (nodes != .array or edges != .array or strings != .array) return error.InvalidSnapshot;
    if (nodes.array.items.len != node_count * node_fields.array.items.len) return error.InvalidSnapshot;
    if (edges.array.items.len != edge_count * edge_fields.array.items.len) return error.InvalidSnapshot;
    if (strings.array.items.len == 0) return error.InvalidSnapshot;
    var has_class = false;
    var has_marker = false;
    for (strings.array.items) |item| {
        if (item != .string) return error.InvalidSnapshot;
        if (std.mem.eql(u8, item.string, "CraneHeapMarkerObject")) has_class = true;
        if (std.mem.eql(u8, item.string, "CRANE_HEAP_MARKER_7F3A")) has_marker = true;
    }
    return std.fmt.allocPrint(arena, "valid v8 heapsnapshot (has_class={}, has_marker={})", .{ has_class, has_marker });
}

/// A fresh directory for one side of a case, the fixtures' files/ copied in;
/// its canonical path.
fn filesDirectory(arena: Allocator, io: Io, options: Options, slug: []const u8, side: []const u8) ![]const u8 {
    const path = try std.fmt.allocPrint(arena, "{s}/files/{s}/{s}", .{ options.out, slug, side });
    const cwd = Io.Dir.cwd();
    try cwd.deleteTree(io, path);
    try cwd.createDirPath(io, path);
    const source_path = try std.fmt.allocPrint(arena, "{s}/files", .{options.fixtures});
    if (cwd.openDir(io, source_path, .{ .iterate = true })) |opened| {
        const source = opened;
        defer source.close(io);
        const target = try cwd.openDir(io, path, .{});
        defer target.close(io);
        var it = source.iterate();
        while (try it.next(io)) |entry| {
            if (entry.kind != .file) continue;
            try source.copyFile(entry.name, target, entry.name, io, .{});
        }
    } else |err| if (err != error.FileNotFound) return err;
    return try cwd.realPathFileAlloc(io, path, arena);
}

/// Chrome's snapshot with its user-agent nodes set apart, numbered as Crane
/// numbers; when the replay does not reproduce Google's lines, the answer
/// stays as it was and says so (`note`), and the case's later uids are not
/// mapped.
fn setApart(gpa: Allocator, arena: Allocator, io: Io, chrome_page: *ChromePage, call: Call, answer: *client.Answer) void {
    const replay = &chrome_page.replay;
    if (replay.broken) {
        answer.note = "user-agent nodes not set apart: an earlier snapshot's replay failed";
        return;
    }
    const verbose = std.mem.eql(u8, call.tool, "take_snapshot") and call.args == .object and
        (if (call.args.object.get("verbose")) |v| v == .bool and v.bool else false);
    const failed = struct {
        fn note(a: Allocator, r: *user_agent.Replay, why: []const u8, err: anyerror) []const u8 {
            r.broken = true;
            return std.fmt.allocPrint(a, "user-agent nodes not set apart: {s} ({t})", .{ why, err }) catch why;
        }
    };
    const url = user_agent.snapshotUrl(answer.text) orelse {
        replay.broken = true;
        answer.note = "user-agent nodes not set apart: the snapshot names no URL";
        return;
    };
    const page = user_agent.readPage(arena, gpa, io, chrome_page.port, url, verbose) catch |err| {
        answer.note = failed.note(arena, replay, "Chrome's page could not be read", err);
        return;
    };
    const kept = page.kept orelse {
        replay.broken = true;
        answer.note = "user-agent nodes not set apart: Chrome's page has no tree";
        return;
    };
    const numbered = replay.number(arena, kept, &page.ua) catch |err| {
        answer.note = failed.note(arena, replay, "the replay failed", err);
        return;
    };
    const agree = user_agent.agrees(arena, answer.text, numbered) catch false;
    if (!agree) {
        replay.broken = true;
        answer.note = "user-agent nodes not set apart: the replay of Google's numbering does not reproduce its lines";
        return;
    }
    var dropped: usize = 0;
    var nodeless: usize = 0;
    for (numbered) |n| switch (n.fate) {
        .drop => dropped += 1,
        .nodeless => nodeless += 1,
        .uid => {},
    };
    const text = user_agent.setApart(arena, answer.text, &replay.fates) catch |err| {
        answer.note = failed.note(arena, replay, "the lines could not be rewritten", err);
        return;
    };
    if (!std.mem.eql(u8, text, answer.text)) answer.raw = answer.text;
    answer.text = text;
    if (dropped + nodeless > 0) answer.note = std.fmt.allocPrint(arena, "Chrome's user-agent shadow nodes set apart: {d} dropped, {d} made nodeless, uids renumbered", .{ dropped, nodeless }) catch "";
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

    const cwd_path = try Io.Dir.cwd().realPathFileAlloc(io, ".", arena);

    var report: Io.Writer.Allocating = .init(arena);
    const w = &report.writer;
    var records: std.ArrayList(CaseRecord) = .empty;
    var equal_cases: usize = 0;
    var expected_cases: usize = 0;
    var ran: usize = 0;
    var case_lines: std.ArrayList([]const u8) = .empty;
    for (cases.cases) |case| {
        if (options.only) |prefix| if (!std.mem.startsWith(u8, case.name, prefix)) continue;
        const slug = try slugOf(arena, case.name);
        // Chrome's remote debugging port beside Puppeteer's pipe, for the
        // harness's own reads of the page (user_agent.zig).
        var chrome_page: ChromePage = .{ .port = try user_agent.freePort(io) };
        const port_arg = try std.fmt.allocPrint(arena, "--chromeArg=--remote-debugging-port={d}", .{chrome_page.port});
        var chrome_places: Places = .{ .origin = origin, .cwd = cwd_path };
        var crane_places: Places = .{ .origin = origin, .cwd = cwd_path };
        var chrome_argv: std.ArrayList([]const u8) = .empty;
        try chrome_argv.appendSlice(arena, &.{ options.node, options.chrome_mcp, "--executablePath", options.chrome, "--headless", "--isolated", "--no-usage-statistics", "--no-performance-crux", port_arg });
        var crane_argv: std.ArrayList([]const u8) = .empty;
        try crane_argv.appendSlice(arena, &.{ options.crane, "--mcp" });
        if (case.memory_debugging) {
            try chrome_argv.append(arena, "--memoryDebugging");
            try crane_argv.append(arena, "--memoryDebugging");
        }
        if (case.category_network_mocks) {
            try chrome_argv.append(arena, "--categoryNetworkMocks");
            try crane_argv.append(arena, "--categoryNetworkMocks");
        }
        if (case.category_experimental_third_party) {
            try chrome_argv.append(arena, "--categoryExperimentalThirdParty");
            try crane_argv.append(arena, "--categoryExperimentalThirdParty");
        }
        if (case.experimental_vision) {
            try chrome_argv.append(arena, "--experimentalVision");
            try crane_argv.append(arena, "--experimentalVision");
        }
        if (case.slim) {
            try chrome_argv.append(arena, "--slim");
            try crane_argv.append(arena, "--slim");
        }
        for (case.flags) |flag| {
            try chrome_argv.append(arena, flag);
            try crane_argv.append(arena, flag);
        }
        if (case.files or case.client_roots) {
            chrome_places.files = try filesDirectory(arena, io, options, slug, "chrome");
            crane_places.files = try filesDirectory(arena, io, options, slug, "crane");
            for (case.copy_fixtures) |fixture_name| {
                const src = try std.fmt.allocPrint(arena, "{s}/{s}", .{ options.fixtures, fixture_name });
                const data = try Io.Dir.cwd().readFileAlloc(io, src, arena, .limited(64 * 1024 * 1024));
                try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ chrome_places.files.?, fixture_name }), .data = data });
                try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ crane_places.files.?, fixture_name }), .data = data });
            }
            if (!case.client_roots) {
                try chrome_argv.appendSlice(arena, &.{ "--filesystemRoot", chrome_places.files.? });
                try crane_argv.appendSlice(arena, &.{ "--filesystemRoot", crane_places.files.? });
            }
        }
        const chrome = runSide(gpa, arena, io, chrome_argv.items, try std.fmt.allocPrint(arena, "{s}/logs/{s}.chrome.log", .{ options.out, slug }), case, chrome_places, &chrome_page);
        for (case.copy_to_crane) |name| {
            const from = try std.fmt.allocPrint(arena, "{s}/{s}", .{ chrome_places.files orelse break, name });
            const data = Io.Dir.cwd().readFileAlloc(io, from, arena, .limited(512 * 1024 * 1024)) catch |err| {
                std.debug.print("mcp_diff: {s}: copying {s} to Crane's side: {t}\n", .{ case.name, name, err });
                continue;
            };
            try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ crane_places.files.?, name }), .data = data });
        }
        const crane = runSide(gpa, arena, io, crane_argv.items, try std.fmt.allocPrint(arena, "{s}/logs/{s}.crane.log", .{ options.out, slug }), case, crane_places, null);
        const equal = chrome.failure == null and crane.failure == null and sameAnswers(chrome.answers, crane.answers);
        const only_expected = !equal and chrome.failure == null and crane.failure == null and differsOnlyWhereExpected(cases, case.name, chrome.answers, crane.answers);
        if (equal) equal_cases += 1;
        if (only_expected) expected_cases += 1;
        ran += 1;
        try records.append(arena, .{
            .case = case,
            .chrome = chrome,
            .crane = crane,
            .equal = equal,
            .only_expected = only_expected,
        });
        try case_lines.append(arena, try caseSection(arena, cases, case, chrome, crane, equal, only_expected));
        std.debug.print("mcp_diff: {s}: {s}\n", .{ case.name, if (equal) "equal" else if (only_expected) "differs where expected" else "DIFFERS" });
    }
    const classified = try classifyTools(arena, cases, records.items);
    var results: Io.Writer.Allocating = .init(arena);
    try writeResultsJson(&results.writer, classified.summary, classified.tools, records.items);
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
        try w.print("{{\"text\":{f},\"isError\":{},\"images\":{d}", .{ std.json.fmt(a.text, .{}), a.is_error, a.images });
        if (a.note.len != 0) try w.print(",\"note\":{f}", .{std.json.fmt(a.note, .{})});
        if (a.raw) |raw| try w.print(",\"raw\":{f}", .{std.json.fmt(raw, .{})});
        try w.writeAll("}");
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
        if (!call.answered()) continue;
        defer index += 1;
        const a: ?client.Answer = if (index < chrome.answers.len) chrome.answers[index] else null;
        const b: ?client.Answer = if (index < crane.answers.len) crane.answers[index] else null;
        if (a != null and b != null and a.?.is_error == b.?.is_error and std.mem.eql(u8, a.?.text, b.?.text)) continue;
        const why = if (expectedFor(cases, case.name, index + 1)) |e| try std.fmt.allocPrint(arena, " (expected: {s})", .{e.reason}) else "";
        try w.print("### call {d}: {s} {s}{s}\n\nChrome{s}{s}:\n\n```\n{s}\n```\n\nCrane{s}:\n\n```\n{s}\n```\n\n", .{
            index + 1,
            if (call.tool.len != 0) call.tool else "tools/list",
            if (call.tool.len != 0) try std.json.Stringify.valueAlloc(arena, call.args, .{}) else try std.json.Stringify.valueAlloc(arena, call.list_tools, .{}),
            why,
            if (a != null and a.?.is_error) " (isError)" else "",
            if (a != null and a.?.note.len != 0) try std.fmt.allocPrint(arena, " ({s})", .{a.?.note}) else "",
            if (a) |x| x.text else "(none)",
            if (b != null and b.?.is_error) " (isError)" else "",
            if (b) |x| x.text else "(none)",
        });
    }
    // The files directory's listing, after the calls.
    if (index < chrome.answers.len or index < crane.answers.len) {
        const a: ?client.Answer = if (index < chrome.answers.len) chrome.answers[index] else null;
        const b: ?client.Answer = if (index < crane.answers.len) crane.answers[index] else null;
        if (!(a != null and b != null and std.mem.eql(u8, a.?.text, b.?.text))) {
            try w.print("### the files written\n\nChrome:\n\n```\n{s}\n```\n\nCrane:\n\n```\n{s}\n```\n\n", .{ if (a) |x| x.text else "(none)", if (b) |x| x.text else "(none)" });
        }
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
    try std.testing.expectEqualStrings("{\"pageId\":1,\"url\":\"http://127.0.0.1:9/x.html\"}", try argsJson(arena, cases.cases[0].calls[0].args, .{ .origin = "http://127.0.0.1:9" }));
    try std.testing.expectEqualStrings("Successfully navigated to {fixture}/x.html.", try normalize(arena, "Successfully navigated to http://127.0.0.1:9/x.html.", .{ .origin = "http://127.0.0.1:9" }));
    // A side's files directory, inside the working directory, and the
    // working directory itself.
    const places: Places = .{ .origin = "http://127.0.0.1:9", .files = "/w/out/files/a/crane", .cwd = "/w" };
    const with_files = try parseCases(arena,
        \\{"cases":[{"name":"f","files":true,"calls":[{"tool":"take_snapshot","args":{"filePath":"{files}/s.txt"}}]}]}
    );
    try std.testing.expectEqualStrings("{\"filePath\":\"/w/out/files/a/crane/s.txt\"}", try argsJson(arena, with_files.cases[0].calls[0].args, places));
    try std.testing.expectEqualStrings("Saved snapshot to {files}/s.txt. Access denied: path \"{cwd}/x.js\"", try normalize(arena, "Saved snapshot to /w/out/files/a/crane/s.txt. Access denied: path \"/w/x.js\"", places));
    const twice = try parseCases(arena,
        \\{"cases":[{"name":"a","calls":[{"tool":"list_pages"}]},{"name":"a","calls":[{"tool":"list_pages"}]}]}
    );
    try std.testing.expectEqualStrings("two cases share a name", try checkCases(twice));
}

test "cases: a tools/list call and a case's flags; the list call has an answer an expected difference can name" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cases = try parseCases(arena,
        \\{"cases":[{"name":"l","flags":["--no-page-id-routing"],"calls":[{"list_tools":["click","nope"]},{"tool":"list_pages"}]}],
        \\ "expected":[{"case":"l","call":2,"reason":"r"}]}
    );
    try std.testing.expectEqualStrings("", try checkCases(cases));
    try std.testing.expectEqualStrings("--no-page-id-routing", cases.cases[0].flags[0]);
    try std.testing.expect(cases.cases[0].calls[0].answered());
    const message = try std.json.parseFromSliceLeaky(std.json.Value, arena,
        \\{"jsonrpc":"2.0","id":3,"result":{"tools":[{"name":"list_pages"},{"name":"click","inputSchema":{"type":"object"}}]}}
    , .{});
    try std.testing.expectEqualStrings("[{\n \"name\": \"click\",\n \"inputSchema\": {\n  \"type\": \"object\"\n }\n},null]", try listedDefinitions(arena, message, &.{ "click", "nope" }));
    const none = try parseCases(arena,
        \\{"cases":[{"name":"n","calls":[{"args":{}}]}]}
    );
    try std.testing.expectEqualStrings("a call names no tool, no tools/list and no sleep", try checkCases(none));
    // A Chrome-only call has no compared answer; another side is refused.
    const one_side = try parseCases(arena,
        \\{"cases":[{"name":"s","files":true,"copy_to_crane":["x.heapsnapshot"],"calls":[{"tool":"take_heapsnapshot","side":"chrome","args":{"pageId":1,"filePath":"{files}/x.heapsnapshot"}},{"tool":"get_heapsnapshot_summary","args":{"filePath":"{files}/x.heapsnapshot"}}]}],
        \\ "expected":[{"case":"s","call":1,"reason":"r"}]}
    );
    try std.testing.expectEqualStrings("", try checkCases(one_side));
    try std.testing.expect(!one_side.cases[0].calls[0].answered());
    const bad_side = try parseCases(arena,
        \\{"cases":[{"name":"b","calls":[{"tool":"list_pages","side":"crane"}]}]}
    );
    try std.testing.expectEqualStrings("a call's side is not \"chrome\"", try checkCases(bad_side));
}

test "the repository's cases file is well formed" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const cases = try parseCases(arena_state.allocator(), @embedFile("cases.json"));
    try std.testing.expectEqualStrings("", try checkCases(cases));
}

test "classifyTools and writeResultsJson produce valid structured summary JSON" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const cases = try parseCases(arena,
        \\{"cases":[{"name":"c1","about":"test","calls":[{"tool":"list_pages"},{"tool":"wait_for"}]}],"expected":[{"case":"c1","call":2,"reason":"visible needs layout"}]}
    );
    var a1 = [_]client.Answer{ .{ .text = "ok", .is_error = false }, .{ .text = "chrome", .is_error = false } };
    var b1 = [_]client.Answer{ .{ .text = "ok", .is_error = false }, .{ .text = "crane", .is_error = true } };
    const recs = [_]CaseRecord{.{
        .case = cases.cases[0],
        .chrome = .{ .answers = &a1 },
        .crane = .{ .answers = &b1 },
        .equal = false,
        .only_expected = true,
    }};
    const res = try classifyTools(arena, cases, &recs);
    try std.testing.expectEqual(@as(usize, 66), res.summary.tools_total);
    try std.testing.expectEqual(@as(usize, 1), res.summary.tools_equal);
    try std.testing.expectEqual(@as(usize, 1), res.summary.tools_expected_diff);
    try std.testing.expectEqual(@as(usize, 0), res.summary.tools_differs);
    try std.testing.expectEqual(@as(usize, 8), res.summary.tools_needs_renderer);
    try std.testing.expectEqual(@as(usize, 10), res.summary.tools_chrome_only);
    // configure_webauthn and the two WebMCP tools wait for lanes webauthn1
    // and webmcp1.
    try std.testing.expectEqual(@as(usize, 3), res.summary.tools_not_implemented);

    var out: Io.Writer.Allocating = .init(arena);
    try writeResultsJson(&out.writer, res.summary, res.tools, &recs);
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, out.written(), .{});
    try std.testing.expectEqual(@as(i64, 1), parsed.object.get("version").?.integer);
    try std.testing.expectEqual(@as(usize, 66), parsed.object.get("tools").?.array.items.len);
    try std.testing.expectEqual(@as(usize, 1), parsed.object.get("cases").?.array.items.len);
    try std.testing.expectEqual(@as(i64, 3), parsed.object.get("summary").?.object.get("toolsNotImplemented").?.integer);
}

test {
    _ = client;
    _ = user_agent;
}
