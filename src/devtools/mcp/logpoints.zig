//! set_logpoints' model, as chrome-devtools-mcp v1.13.0 builds it
//! (src/LogpointManager.ts, src/formatters/LogpointFormatter.ts,
//! src/devtools/DevtoolsUtils.ts createTargetUniverse; Copyright 2026 Google
//! LLC, Apache-2.0; THIRD_PARTY_NOTICES.md) over the DevTools frontend's
//! BreakpointManager, which it runs in a second CDP session on the page - its
//! "DevTools universe". The frontend's parts are reproduced, not copied
//! (devtools-frontend, BSD-3: front_end/models/breakpoints/
//! BreakpointManager.ts Breakpoint / ModelBreakpoint / Storage.computeId and
//! backendCondition, front_end/models/bindings/ResourceScriptMapping.ts and
//! DebuggerWorkspaceBinding.normalizeUILocation, front_end/core/sdk/
//! DebuggerModel.ts enableDebugger and Location, Script.containsLocation):
//!
//! - the universe: a second session, attached the first time a page tool
//!   runs on the page (McpPage.init), its Debugger enabled as DevTools does
//!   with "skip all pauses" set - so a `debugger` statement never pauses,
//!   while a breakpoint's condition still runs;
//! - the workspace: the URLs of the page's parsed scripts (an inline
//!   script's is its document's) and the document's own;
//! - a logpoint: a breakpoint whose condition is
//!   `/** DEVTOOLS_LOGPOINT */ console.log(<expression>)` with the sourceURL
//!   debugger://logpoint, set by URL, kept by (url, line, column) - the
//!   column 0 once the location reaches a script (DevTools' Location) - and
//!   bound while V8 has resolved it in a live script.
//!
//! Original sources through source maps are batch 4b item 3b; minified-name
//! substitution (NamesResolver) item 3c.

const std = @import("std");
const Allocator = std.mem.Allocator;
const session_mod = @import("session.zig");
const Session = session_mod.Session;
const Page = session_mod.Page;
const str = session_mod.str;

/// LOGPOINT_FORMAT.
pub const logpoint_format = "<url>:<lineNumber>[:<columnNumber>] <expression>";

/// One logpoint as the tool's text gives it (parseLogpoint): a 1-based line
/// and column, all slices of that text.
pub const Request = struct {
    url: []const u8,
    line: u64,
    column: ?u64,
    expression: []const u8,
};

/// What parseLogpoint makes of `text`: the logpoint, or its error message.
pub const Parsed = union(enum) {
    ok: Request,
    invalid,
    not_one_based,
};

/// JavaScript's String.prototype.trim and \s, for ASCII.
fn isSpace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0x0b or c == 0x0c;
}

fn digitsAt(text: []const u8, start: usize) usize {
    var end = start;
    while (end < text.len and std.ascii.isDigit(text[end])) end += 1;
    return end - start;
}

/// Number(digits): exact up to 2^64-1, saturated past it.
fn number(digits: []const u8) u64 {
    return std.fmt.parseInt(u64, digits, 10) catch std.math.maxInt(u64);
}

/// parseLogpoint: `/^(\S+?):(\d+)(?::(\d+))?\s+(\S.*)$/s` on the trimmed
/// text - the location is the shortest prefix ending in one or two numbers
/// and whitespace (a URL may hold colons: a port) - then the 1-based check.
pub fn parse(text: []const u8) Parsed {
    const t = std.mem.trim(u8, text, " \t\n\r\x0b\x0c");
    var i: usize = 1;
    while (i < t.len) : (i += 1) {
        // \S+? cannot cross whitespace: no later colon can start a match.
        if (isSpace(t[i - 1])) break;
        if (t[i] != ':') continue;
        const line_start = i + 1;
        const line_len = digitsAt(t, line_start);
        if (line_len == 0) continue;
        const after_line = line_start + line_len;
        var column: ?[]const u8 = null;
        var rest_start = after_line;
        // (?::(\d+))? first, as the greedy group tries.
        if (after_line < t.len and t[after_line] == ':') {
            const column_len = digitsAt(t, after_line + 1);
            const after_column = after_line + 1 + column_len;
            if (column_len > 0 and after_column < t.len and isSpace(t[after_column])) {
                column = t[after_line + 1 .. after_column];
                rest_start = after_column;
            }
        }
        // \s+(\S.*)$: whitespace, then the rest from its first non-space.
        if (rest_start >= t.len or !isSpace(t[rest_start])) continue;
        var expression_start = rest_start;
        while (expression_start < t.len and isSpace(t[expression_start])) expression_start += 1;
        if (expression_start >= t.len) continue;
        const request: Request = .{
            .url = t[0..i],
            .line = number(t[line_start..after_line]),
            .column = if (column) |c| number(c) else null,
            .expression = t[expression_start..],
        };
        if (request.line < 1 or (request.column != null and request.column.? == 0)) return .not_one_based;
        return .{ .ok = request };
    }
    return .invalid;
}

/// A script V8 parsed in the page (Debugger.scriptParsed on the universe's
/// session): what DevTools' Script keeps of it for logpoints. OWNED.
pub const Script = struct {
    id: []u8,
    url: []u8,
    start_line: i64,
    start_column: i64,
    end_line: i64,
    end_column: i64,
    context_id: i64,

    fn deinit(self: *Script, allocator: Allocator) void {
        allocator.free(self.id);
        allocator.free(self.url);
    }
};

/// One logpoint: DevTools' Breakpoint (its storage state's url, line,
/// column and condition) with its ModelBreakpoint's backend id and the
/// scripts V8 resolved it in. OWNED.
pub const Logpoint = struct {
    url: []u8,
    /// 0-based, as the model keeps it.
    line: u64,
    column: ?u64,
    expression: []u8,
    breakpoint_id: ?[]u8 = null,
    /// The scripts of its resolved locations (Breakpoint.#uiLocations).
    resolved: std.ArrayList([]u8) = .empty,

    /// Breakpoint.bound.
    pub fn bound(self: *const Logpoint) bool {
        return self.resolved.items.len != 0;
    }

    pub fn clearResolved(self: *Logpoint, allocator: Allocator) void {
        for (self.resolved.items) |id| allocator.free(id);
        self.resolved.clearRetainingCapacity();
    }

    pub fn destroy(self: *Logpoint, allocator: Allocator) void {
        allocator.free(self.url);
        allocator.free(self.expression);
        if (self.breakpoint_id) |id| allocator.free(id);
        self.clearResolved(allocator);
        self.resolved.deinit(allocator);
        allocator.destroy(self);
    }
};

/// A page's logpoint state: the universe's scripts and the logpoints (the
/// manager's #records, in their order).
pub const State = struct {
    scripts: std.ArrayList(Script) = .empty,
    records: std.ArrayList(*Logpoint) = .empty,
    /// McpPage's #logpointManager exists: made on the first call that names
    /// a logpoint.
    manager: bool = false,

    pub fn deinit(self: *State, allocator: Allocator) void {
        for (self.scripts.items) |*s| s.deinit(allocator);
        self.scripts.deinit(allocator);
        for (self.records.items) |r| r.destroy(allocator);
        self.records.deinit(allocator);
        self.* = .{};
    }

    /// An event of the universe's session.
    pub fn debuggerEvent(self: *State, allocator: Allocator, method: []const u8, params: std.json.ObjectMap) !void {
        if (std.mem.eql(u8, method, "Debugger.scriptParsed")) {
            const id = str(params.get("scriptId"));
            if (id.len == 0) return;
            const id_copy = try allocator.dupe(u8, id);
            errdefer allocator.free(id_copy);
            const url_copy = try allocator.dupe(u8, str(params.get("url")));
            errdefer allocator.free(url_copy);
            try self.scripts.append(allocator, .{
                .id = id_copy,
                .url = url_copy,
                .start_line = int(params.get("startLine")),
                .start_column = int(params.get("startColumn")),
                .end_line = int(params.get("endLine")),
                .end_column = int(params.get("endColumn")),
                .context_id = int(params.get("executionContextId")),
            });
            return;
        }
        if (std.mem.eql(u8, method, "Debugger.breakpointResolved")) {
            const id = str(params.get("breakpointId"));
            const location = params.get("location") orelse return;
            if (location != .object) return;
            const script_id = str(location.object.get("scriptId"));
            for (self.records.items) |r| {
                const own = r.breakpoint_id orelse continue;
                if (!std.mem.eql(u8, own, id)) continue;
                const copy = try allocator.dupe(u8, script_id);
                errdefer allocator.free(copy);
                try r.resolved.append(allocator, copy);
            }
        }
    }

    /// A context went away (Runtime.executionContextDestroyed on the page's
    /// session): its scripts, and the locations resolved in them
    /// (ModelBreakpoint.resetLocations on the global object's clear).
    pub fn contextDestroyed(self: *State, allocator: Allocator, context_id: i64) void {
        var i: usize = 0;
        while (i < self.scripts.items.len) {
            const s = &self.scripts.items[i];
            if (s.context_id != context_id) {
                i += 1;
                continue;
            }
            self.dropResolvedIn(allocator, s.id);
            s.deinit(allocator);
            _ = self.scripts.orderedRemove(i);
        }
    }

    /// Every context went away (Runtime.executionContextsCleared).
    pub fn contextsCleared(self: *State, allocator: Allocator) void {
        for (self.scripts.items) |*s| s.deinit(allocator);
        self.scripts.clearRetainingCapacity();
        for (self.records.items) |r| r.clearResolved(allocator);
    }

    fn dropResolvedIn(self: *State, allocator: Allocator, script_id: []const u8) void {
        for (self.records.items) |r| {
            var j: usize = 0;
            while (j < r.resolved.items.len) {
                if (std.mem.eql(u8, r.resolved.items[j], script_id)) {
                    allocator.free(r.resolved.orderedRemove(j));
                } else j += 1;
            }
        }
    }

    /// The workspace's Network project, in order: the document, then each
    /// parsed script's URL (an inline script's is its document's), once
    /// each. DevTools' own internal scripts (debugger:// - a breakpoint's
    /// condition) and scripts with no URL have no source code there.
    pub fn sourceUrls(self: *const State, arena: Allocator, document: []const u8) ![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        if (isNetworkUrl(document)) try out.append(arena, document);
        for (self.scripts.items) |s| {
            if (s.url.len == 0 or std.mem.startsWith(u8, s.url, "debugger://")) continue;
            var seen = false;
            for (out.items) |u| if (std.mem.eql(u8, u, s.url)) {
                seen = true;
                break;
            };
            if (!seen) try out.append(arena, s.url);
        }
        return out.items;
    }

    /// Some script has this URL: a location in its source code is a raw
    /// location (ResourceScriptMapping), whose column is 0 when none was
    /// given (DevTools' Location).
    pub fn hasScript(self: *const State, url: []const u8) bool {
        for (self.scripts.items) |s| if (std.mem.eql(u8, s.url, url)) return true;
        return false;
    }

    /// The record at (url, line, column): Storage.computeId's key.
    pub fn find(self: *const State, url: []const u8, line: u64, column: ?u64) ?*Logpoint {
        for (self.records.items) |r| {
            if (r.line != line or !std.mem.eql(u8, r.url, url)) continue;
            if ((r.column == null) != (column == null)) continue;
            if (r.column != null and r.column.? != column.?) continue;
            return r;
        }
        return null;
    }
};

/// A document the workspace's Network project holds a source code for.
fn isNetworkUrl(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://") or std.mem.startsWith(u8, url, "file://");
}

fn int(value: ?std.json.Value) i64 {
    const v = value orelse return 0;
    return switch (v) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => 0,
    };
}

/// Breakpoint.backendCondition for a logpoint: LOGPOINT_PREFIX, the
/// expression, LOGPOINT_SUFFIX, and the condition's sourceURL.
pub fn backendCondition(arena: Allocator, expression: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "/** DEVTOOLS_LOGPOINT */ console.log({s})\n\n//# sourceURL=debugger://logpoint", .{expression});
}

/// The final path segment, lowercased (LogpointManager's baseName).
pub fn baseName(arena: Allocator, url: []const u8) ![]const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, url, '/');
    return std.ascii.allocLowerString(arena, if (slash) |s| url[s + 1 ..] else url);
}

/// LogpointManager's locationKey: the url and the line and column asked for.
pub fn locationKey(arena: Allocator, url: []const u8, line: u64, column: ?u64) ![]const u8 {
    if (column) |c| return std.fmt.allocPrint(arena, "{s}:{d}:{d}", .{ url, line, c });
    return std.fmt.allocPrint(arena, "{s}:{d}", .{ url, line });
}

/// LogpointFormatter: the logpoints, or that there are none.
pub fn formatList(arena: Allocator, records: []const *Logpoint) ![]const u8 {
    if (records.len == 0) return "No logpoints are set on the page.";
    var out: std.Io.Writer.Allocating = .init(arena);
    try out.writer.print("{d} logpoint(s) set on the page:", .{records.len});
    for (records) |r| {
        try out.writer.print("\n- {s}:{d}", .{ r.url, r.line + 1 });
        if (r.column) |c| try out.writer.print(":{d}", .{c + 1});
        const status = if (r.bound()) "bound" else "not bound (no parsed script contains the location)";
        try out.writer.print(" logging `{s}` [{s}]", .{ r.expression, status });
    }
    return out.written();
}

/// McpPage.init's #initDevToolsUniverseNoThrow: the universe's session on
/// the page, once - createTargetUniverse's target over a new session
/// (Target.attachToTarget, flattened), whose DebuggerModel starts as
/// enableDebugger does: skip all pauses (the universe's setting), enable
/// with DevTools' script cache (1e8 bytes), no pause on exceptions, async
/// stacks 32 deep. A failure is logged, as Google's server logs it, and
/// tried again at the next page tool.
pub fn initUniverse(session: *Session, page: *Page) !void {
    if (page.debugger_session_id != null or page.closed) return;
    var params_buffer: [256]u8 = undefined;
    const params = std.fmt.bufPrint(&params_buffer, "{{\"targetId\":{f},\"flatten\":true}}", .{std.json.fmt(page.target_id, .{})}) catch return;
    var r = session.client.call("Target.attachToTarget", params, "", session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return,
    };
    defer r.deinit();
    const result = r.result() orelse return;
    const id = str(result.object.get("sessionId"));
    if (id.len == 0) return;
    page.debugger_session_id = try session.allocator.dupe(u8, id);
    const steps = [_][2][]const u8{
        .{ "Debugger.setSkipAllPauses", "{\"skip\":true}" },
        .{ "Debugger.enable", "{\"maxScriptsCacheSize\":100000000}" },
        .{ "Debugger.setPauseOnExceptions", "{\"state\":\"none\"}" },
        .{ "Debugger.setAsyncCallStackDepth", "{\"maxDepth\":32}" },
    };
    for (steps) |step| {
        var answer = session.client.call(step[0], step[1], page.debugger_session_id.?, session_mod.command_timeout_ms) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return,
        };
        answer.deinit();
    }
}

test "parse: the shortest location, a port's colon, a column, the 1-based check" {
    const t = std.testing;
    const a = parse("src/app.ts:42 'total', cart.total").ok;
    try t.expectEqualStrings("src/app.ts", a.url);
    try t.expectEqual(@as(u64, 42), a.line);
    try t.expect(a.column == null);
    try t.expectEqualStrings("'total', cart.total", a.expression);
    const b = parse("  http://localhost:8080/a.js:3:7   x, y  ").ok;
    try t.expectEqualStrings("http://localhost:8080/a.js", b.url);
    try t.expectEqual(@as(u64, 3), b.line);
    try t.expectEqual(@as(u64, 7), b.column.?);
    try t.expectEqualStrings("x, y", b.expression);
    // A column with no whitespace after it is no column: the line must be
    // followed by whitespace.
    try t.expect(parse("a.js:3:x y") == .invalid);
    try t.expect(parse("a.js 1") == .invalid);
    try t.expect(parse("a.js:1") == .invalid);
    try t.expect(parse("a.js:0 x") == .not_one_based);
    try t.expect(parse("a.js:1:0 x") == .not_one_based);
    // The expression may span lines (the s flag).
    try t.expectEqualStrings("a,\nb", parse("a.js:1 a,\nb").ok.expression);
}

test "formatList: none, bound and not, a column only when the model has one" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    try t.expectEqualStrings("No logpoints are set on the page.", try formatList(arena, &.{}));
    var url_a = "http://h/a.js".*;
    var url_b = "http://h/b.html".*;
    var e1 = "'x', x".*;
    var e2 = "y".*;
    var bound_id = "1".*;
    var first: Logpoint = .{ .url = &url_a, .line = 3, .column = 0, .expression = &e1 };
    try first.resolved.append(arena, &bound_id);
    var second: Logpoint = .{ .url = &url_b, .line = 1, .column = null, .expression = &e2 };
    try t.expectEqualStrings(
        "2 logpoint(s) set on the page:\n- http://h/a.js:4:1 logging `'x', x` [bound]\n- http://h/b.html:2 logging `y` [not bound (no parsed script contains the location)]",
        try formatList(arena, &.{ &first, &second }),
    );
}
