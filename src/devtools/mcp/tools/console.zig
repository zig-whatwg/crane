//! list_console_messages and get_console_message - chrome-devtools-mcp's
//! src/tools/console.ts (chrome-devtools-mcp-v1.13.0), with McpResponse's
//! console sections (#handleConsoleList, #handleAttachedConsoleMessage,
//! format's "## Console messages", #dataWithPagination) and
//! ConsoleFormatter.from's detailed data: each argument resolved as
//! Puppeteer's JSHandle.jsonValue does (Runtime.callFunctionOn by value), an
//! error argument or an uncaught error symbolized as SymbolizedError does
//! (Runtime.getExceptionDetails for its stack, Runtime.getProperties for its
//! `cause`, ten deep). Translated from chrome-devtools-mcp's TypeScript
//! (Copyright 2025 Google LLC, Apache-2.0; THIRD_PARTY_NOTICES.md).

const std = @import("std");
const Allocator = std.mem.Allocator;
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const console = @import("../console.zig");
const lp = @import("../logpoints.zig");

pub const list = [_]Tool{
    .{ .name = "get_console_message", .page_tool = true, .run = getConsoleMessage },
    .{ .name = "list_console_messages", .page_tool = true, .run = listConsoleMessages },
};

/// FILTERABLE_MESSAGE_TYPES.
pub const filterable_types = [_][]const u8{ "log", "debug", "info", "error", "warn", "dir", "dirxml", "table", "trace", "clear", "startGroup", "startGroupCollapsed", "endGroup", "assert", "profile", "profileEnd", "count", "timeEnd", "verbose", "issue" };

/// SymbolizedError's MAX_CAUSE_DEPTH.
const max_cause_depth = 10;

fn listConsoleMessages(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    if (registry.stringArg(args, "serviceWorkerId") != null) return ctx.failPlain("Service worker not found.", .{});
    const include_preserved = registry.boolArg(args, "includePreservedMessages") orelse false;
    const include_stacks = registry.boolArg(args, "includeStackTraces") orelse false;
    var messages = try target.console.data(ctx.arena, include_preserved);
    // types: only those kinds ("issue" matches none: Crane reports none).
    if (args.get("types")) |types| if (types == .array and types.array.items.len > 0) {
        var kept: std.ArrayList(*console.Message) = .empty;
        for (messages) |m| {
            for (types.array.items) |t| if (t == .string and std.mem.eql(u8, t.string, m.type)) {
                try kept.append(ctx.arena, m);
                break;
            };
        }
        messages = kept.items;
    };
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(ctx.arena, "## Console messages");
    if (messages.len == 0) {
        try lines.append(ctx.arena, "<no console messages found>");
        response.console_list = lines.items;
        return;
    }
    // groupConsecutive.
    const Group = struct { message: *console.Message, count: u32 };
    var groups: std.ArrayList(Group) = .empty;
    for (messages) |m| {
        if (groups.items.len > 0 and console.sameGroup(groups.items[groups.items.len - 1].message, m)) {
            groups.items[groups.items.len - 1].count += 1;
        } else try groups.append(ctx.arena, .{ .message = m, .count = 1 });
    }
    const page_size = pageSize(args);
    const shown = try paginate(ctx.arena, groups.items.len, page_size, pageIdx(args), &lines);
    var any_stack = false;
    for (groups.items[shown.start..shown.end]) |group| {
        var out: std.Io.Writer.Allocating = .init(ctx.arena);
        var stack: ?[]const u8 = null;
        if (include_stacks) {
            const trace = try messageStack(ctx, target, group.message);
            if (trace) |t| {
                const formatted = try formatStackTraceResolved(ctx, target, t.stack_json, t.cause_lines, false);
                if (formatted.len != 0) {
                    stack = formatted;
                    any_stack = true;
                }
            }
        }
        try console.writeConcise(&out.writer, group.message, group.count, stack);
        try lines.append(ctx.arena, out.written());
    }
    if (any_stack) try lines.append(ctx.arena, "Note: stack trace line and column numbers use 1-based indexing");
    response.console_list = lines.items;
}

fn getConsoleMessage(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const id_value = registry.numberArg(args, "msgid") orelse return ctx.fail("Input validation error: Invalid arguments for tool get_console_message: msgid: Invalid input: expected number, received undefined", .{});
    // McpResponse: a falsy msgid attaches nothing.
    if (id_value == 0) return;
    // Looked up in McpResponse.handle: its failure is the message alone.
    if (id_value < 1 or id_value != @floor(id_value) or id_value > std.math.maxInt(u32)) return ctx.failPlain("Request not found for selected page", .{});
    const id: u32 = @intFromFloat(id_value);
    const message = target.console.byId(id) orelse return ctx.failPlain("Request not found for selected page", .{});
    response.detailed_console = try detailed(ctx, target, message);
}

/// toStringDetailed of ConsoleFormatter.from(message, {fetchDetailedData}).
fn detailed(ctx: *Context, page: *Page, message: *console.Message) ![]const u8 {
    const arena = ctx.arena;
    var text: []const u8 = message.text;
    var stack_text: ?[]const u8 = null;
    var arg_texts: std.ArrayList([]const u8) = .empty;
    if (message.uncaught) {
        const details = try std.json.parseFromSliceLeaky(std.json.Value, arena, message.detail_json, .{});
        const symbolized = try fromDetails(ctx, page, details.object, 0);
        text = symbolized.message;
        if (symbolized.stack_json) |s| {
            const formatted = try formatStackTraceResolved(ctx, page, s, try causeLines(ctx, page, symbolized.cause), true);
            if (formatted.len != 0) stack_text = formatted;
        }
    } else {
        const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, message.detail_json, .{});
        var resolved: std.ArrayList([]const u8) = .empty;
        if (parsed == .array) for (parsed.array.items, 0..) |arg, i| {
            const value = resolveArg(ctx, page, arg) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => try std.fmt.allocPrint(arena, "<error: Argument {d} is no longer available>", .{i}),
            };
            try resolved.append(arena, value);
        };
        // #getText and #getArgs: with no text, the first argument is it.
        if (text.len == 0 and resolved.items.len > 0) {
            text = resolved.items[0];
            try arg_texts.appendSlice(arena, resolved.items[1..]);
        } else try arg_texts.appendSlice(arena, resolved.items);
        if (message.stack_json.len != 0) {
            const formatted = try formatStackTraceResolved(ctx, page, message.stack_json, &.{}, true);
            if (formatted.len != 0) stack_text = formatted;
        }
    }
    var lines: std.ArrayList([]const u8) = .empty;
    try lines.append(arena, try std.fmt.allocPrint(arena, "ID: {d}", .{message.id}));
    try lines.append(arena, try std.fmt.allocPrint(arena, "Message: {s}> {s}", .{ message.type, text }));
    if (arg_texts.items.len > 0) {
        try lines.append(arena, "### Arguments");
        for (arg_texts.items, 0..) |a, i| try lines.append(arena, try std.fmt.allocPrint(arena, "Arg #{d}: {s}", .{ i, a }));
    }
    if (stack_text) |s| {
        try lines.append(arena, "### Stack trace");
        try lines.append(arena, s);
    }
    return std.mem.join(arena, "\n", lines.items);
}

/// One argument as ConsoleFormatter.from resolves and formatArg prints it.
fn resolveArg(ctx: *Context, page: *Page, arg: std.json.Value) ![]const u8 {
    const arena = ctx.arena;
    if (arg != .object) return error.Unavailable;
    const remote = arg.object;
    const kind = session_mod.str(remote.get("type"));
    if (std.mem.eql(u8, kind, "object") and std.mem.eql(u8, session_mod.str(remote.get("subtype")), "error")) {
        const symbolized = try fromError(ctx, page, remote, 0);
        return formatSymbolized(ctx, page, symbolized);
    }
    if (!console.isJsonLike(remote)) return console.formatRemoteObject(arena, remote);
    const object_id = remote.get("objectId") orelse {
        // valueFromRemoteObject, then String() (an object's JSON.stringify:
        // null prints "null").
        var out: std.Io.Writer.Allocating = .init(arena);
        if (remote.get("unserializableValue")) |u| {
            const literal = session_mod.str(u);
            try out.writer.writeAll(if (std.mem.eql(u8, literal, "-0")) "0" else literal);
        } else if (remote.get("value")) |v| {
            if (v == .null) try out.writer.writeAll("null") else if (v == .object or v == .array) try console.jsonStringify(&out.writer, v) else try console.jsString(&out.writer, v);
        } else try out.writer.writeAll("undefined");
        return out.written();
    };
    // JSHandle.jsonValue: the object by value; JSON can't carry it (a
    // cycle): the preview describes it.
    const params = try std.fmt.allocPrint(arena, "{{\"functionDeclaration\":\"(object => object)\",\"objectId\":{f},\"arguments\":[{{\"objectId\":{f}}}],\"returnByValue\":true,\"awaitPromise\":true}}", .{ std.json.fmt(object_id, .{}), std.json.fmt(object_id, .{}) });
    var r = try ctx.session.client.call("Runtime.callFunctionOn", params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    const ok = if (r.result()) |result| result.object.get("exceptionDetails") == null else false;
    if (ok) {
        const value_remote = r.result().?.object.get("result").?.object;
        if (value_remote.get("value")) |v| {
            var out: std.Io.Writer.Allocating = .init(arena);
            if (v == .object or v == .array or v == .null) try console.jsonStringify(&out.writer, v) else try console.jsString(&out.writer, v);
            return out.written();
        }
    }
    if (remote.get("preview") != null) return console.formatRemoteObject(arena, remote);
    return error.Unavailable;
}

const Symbolized = struct {
    message: []const u8,
    /// The Runtime.StackTrace's JSON, when there is one.
    stack_json: ?[]const u8 = null,
    cause: ?*Symbolized = null,
};

/// The stack and cause an entry prints with includeStackTraces.
const MessageStack = struct { stack_json: []const u8, cause_lines: []const []const u8 };

fn messageStack(ctx: *Context, page: *Page, message: *console.Message) !?MessageStack {
    if (!message.uncaught) {
        if (message.stack_json.len == 0) return null;
        return .{ .stack_json = message.stack_json, .cause_lines = &.{} };
    }
    const details = try std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, message.detail_json, .{});
    const symbolized = try fromDetails(ctx, page, details.object, 0);
    const stack = symbolized.stack_json orelse return null;
    return .{ .stack_json = stack, .cause_lines = try causeLines(ctx, page, symbolized.cause) };
}

/// SymbolizedError.#fromDetails with includeStackAndCause.
fn fromDetails(ctx: *Context, page: *Page, details: std.json.ObjectMap, depth: u32) !Symbolized {
    const arena = ctx.arena;
    var result: Symbolized = .{ .message = try console.exceptionMessage(arena, details) };
    if (details.get("stackTrace")) |s| if (s == .object) {
        result.stack_json = try std.json.Stringify.valueAlloc(arena, s, .{});
    };
    if (depth < max_cause_depth) if (details.get("exception")) |exception| if (exception == .object) {
        if (lookupCause(ctx, page, exception.object) catch null) |cause_remote| {
            if (fromError(ctx, page, cause_remote, depth + 1)) |cause| {
                const owned = try arena.create(Symbolized);
                owned.* = cause;
                result.cause = owned;
            } else |err| if (err == error.OutOfMemory) return err;
        }
    };
    return result;
}

/// SymbolizedError.#fromError.
fn fromError(ctx: *Context, page: *Page, remote: std.json.ObjectMap, depth: u32) anyerror!Symbolized {
    if (try exceptionDetails(ctx, page, remote)) |details| return fromDetails(ctx, page, details, depth);
    var out: std.Io.Writer.Allocating = .init(ctx.arena);
    try console.messageFromException(&out.writer, remote);
    return .{ .message = out.written() };
}

fn isErrorLike(remote: std.json.ObjectMap) bool {
    // `error.type !== 'object' && error.subtype !== 'error'` refuses.
    return std.mem.eql(u8, session_mod.str(remote.get("type")), "object") or std.mem.eql(u8, session_mod.str(remote.get("subtype")), "error");
}

/// #getExceptionDetails: Runtime.getExceptionDetails for an object.
fn exceptionDetails(ctx: *Context, page: *Page, remote: std.json.ObjectMap) !?std.json.ObjectMap {
    if (!isErrorLike(remote)) return null;
    const object_id = remote.get("objectId") orelse return null;
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"errorObjectId\":{f}}}", .{std.json.fmt(object_id, .{})});
    var r = try ctx.session.client.call("Runtime.getExceptionDetails", params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    const result = r.result() orelse return error.ProtocolError;
    const details = result.object.get("exceptionDetails") orelse return null;
    if (details != .object) return null;
    // Copied out of the response, which is freed here.
    const copy = try std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, try std.json.Stringify.valueAlloc(ctx.arena, details, .{}), .{});
    return copy.object;
}

/// #lookupCause: the object's own `cause` property.
fn lookupCause(ctx: *Context, page: *Page, remote: std.json.ObjectMap) !?std.json.ObjectMap {
    if (!isErrorLike(remote)) return null;
    const object_id = remote.get("objectId") orelse return null;
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"objectId\":{f}}}", .{std.json.fmt(object_id, .{})});
    var r = try ctx.session.client.call("Runtime.getProperties", params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    const result = r.result() orelse return null;
    const props = result.object.get("result") orelse return null;
    if (props != .array) return null;
    for (props.array.items) |p| {
        if (p != .object or !std.mem.eql(u8, session_mod.str(p.object.get("name")), "cause")) continue;
        const value = p.object.get("value") orelse return null;
        if (value != .object) return null;
        const copy = try std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, try std.json.Stringify.valueAlloc(ctx.arena, value, .{}), .{});
        return copy.object;
    }
    return null;
}

/// formatCause's lines (with source-map resolution + ignoreList filtering).
fn causeLines(ctx: *Context, page: *Page, cause: ?*Symbolized) ![]const []const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    var next = cause;
    while (next) |c| {
        try lines.append(ctx.arena, try std.fmt.allocPrint(ctx.arena, "Caused by: {s}", .{c.message}));
        if (c.stack_json) |s| {
            try ensureStackSourceMaps(ctx, page, s);
            try stackLinesResolved(ctx.arena, &page.logpoints, s, &lines);
        }
        next = c.cause;
    }
    return lines.items;
}

/// formatArg of a SymbolizedError: its message, then its stack trace (with
/// the causes) when it has one.
fn formatSymbolized(ctx: *Context, page: *Page, symbolized: Symbolized) ![]const u8 {
    const stack = symbolized.stack_json orelse return symbolized.message;
    const trace = try formatStackTraceResolved(ctx, page, stack, try causeLines(ctx, page, symbolized.cause), true);
    if (trace.len == 0) return symbolized.message;
    return std.fmt.allocPrint(ctx.arena, "{s}\n{s}", .{ symbolized.message, trace });
}

// ----------------------------------------------------------------------------
// Source-map-resolved stack trace formatting (reusing logpoints/source_map.zig)
// ----------------------------------------------------------------------------

const stack_trace_max_lines = 50;

fn formatStackTraceResolved(
    ctx: *Context,
    page: *Page,
    stack_json: []const u8,
    cause_lines: []const []const u8,
    include_note: bool,
) ![]const u8 {
    try ensureStackSourceMaps(ctx, page, stack_json);
    return formatStackTraceWithState(ctx.arena, &page.logpoints, stack_json, cause_lines, include_note);
}

fn formatStackTraceWithState(
    arena: Allocator,
    state: *const lp.State,
    stack_json: []const u8,
    cause_lines: []const []const u8,
    include_note: bool,
) ![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    try stackLinesResolved(arena, state, stack_json, &lines);
    try lines.appendSlice(arena, cause_lines);
    if (lines.items.len == 0) return "";
    var out: std.ArrayList([]const u8) = .empty;
    const kept = @min(lines.items.len, stack_trace_max_lines);
    try out.appendSlice(arena, lines.items[0..kept]);
    if (lines.items.len > kept) try out.append(arena, try std.fmt.allocPrint(arena, "... and {d} more frames", .{lines.items.len - kept}));
    if (include_note) try out.append(arena, "Note: line and column numbers use 1-based indexing");
    return std.mem.join(arena, "\n", out.items);
}

/// Start & await source map loads for any script referenced by `stack_json`.
fn ensureStackSourceMaps(ctx: *Context, page: *Page, stack_json: []const u8) !void {
    if (stack_json.len == 0) return;
    const state = &page.logpoints;
    _ = state.pollLoads();
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, stack_json, .{}) catch return;
    if (parsed != .object) return;

    var need_wait = false;
    var fragment: ?std.json.ObjectMap = parsed.object;
    while (fragment) |f| {
        if (f.get("callFrames")) |cf| if (cf == .array) for (cf.array.items) |frame| {
            if (frame != .object) continue;
            const script_id = session_mod.str(frame.object.get("scriptId"));
            const url = session_mod.str(frame.object.get("url"));
            const line = jsonNumber(frame.object.get("lineNumber"));
            const col = jsonNumber(frame.object.get("columnNumber"));
            const idx = findScriptIndex(state, script_id, url, line, col) orelse continue;
            const script = &state.scripts.items[idx];
            if (script.source_map_url.len == 0 or script.has_syntax_error) continue;
            if (script.map_state == .none) {
                state.startMapLoad(ctx.session.allocator, script, page.url, &ctx.session.paths);
            }
            if (script.map_state == .loading) need_wait = true;
        };
        fragment = if (f.get("parent")) |p| (if (p == .object) p.object else null) else null;
    }
    if (need_wait) {
        _ = try state.waitForMaps(ctx.session, page, null);
    }
}

fn findScriptIndex(state: *const lp.State, script_id: []const u8, url: []const u8, line: i64, col: i64) ?usize {
    if (script_id.len != 0) {
        for (state.scripts.items, 0..) |s, idx| {
            if (std.mem.eql(u8, s.id, script_id)) return idx;
        }
    }
    if (url.len != 0) {
        // Prefer the newest parsed script matching `url` whose span contains (line, col).
        var fallback: ?usize = null;
        var i = state.scripts.items.len;
        while (i > 0) {
            i -= 1;
            const s = &state.scripts.items[i];
            if (!std.mem.eql(u8, s.url, url)) continue;
            if (s.containsLocation(line, col)) return i;
            if (fallback == null) fallback = i;
        }
        return fallback;
    }
    return null;
}

fn stackLinesResolved(arena: Allocator, state: *const lp.State, stack_json: []const u8, lines: *std.ArrayList([]const u8)) !void {
    if (stack_json.len == 0) return;
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, arena, stack_json, .{}) catch return;
    if (parsed != .object) return;
    var fragment: ?std.json.ObjectMap = parsed.object;
    var first = true;
    while (fragment) |f| {
        var frames: std.ArrayList([]const u8) = .empty;
        if (f.get("callFrames")) |cf| if (cf == .array) for (cf.array.items) |frame| {
            if (frame != .object) continue;
            if (try formatFrameResolved(arena, state, frame.object)) |formatted| {
                try frames.append(arena, formatted);
            }
        };
        if (!first and frames.items.len > 0) {
            const description = session_mod.str(f.get("description"));
            const prefix = try std.fmt.allocPrint(arena, "--- {s} ", .{if (description.len != 0) description else "async"});
            const dashes = 40 -| prefix.len;
            const separator = try arena.alloc(u8, prefix.len + dashes);
            @memcpy(separator[0..prefix.len], prefix);
            @memset(separator[prefix.len..], '-');
            try lines.append(arena, separator);
        }
        try lines.appendSlice(arena, frames.items);
        first = false;
        fragment = if (f.get("parent")) |p| (if (p == .object) p.object else null) else null;
    }
}

/// Resolve a call frame through its script's Source Map V3 (if loaded) and
/// filter ignore-listed frames (`ignoreList` / `x_google_ignoreList`).
/// Returns null when the frame is ignore-listed.
fn formatFrameResolved(arena: Allocator, state: *const lp.State, frame: std.json.ObjectMap) !?[]const u8 {
    const name = session_mod.str(frame.get("functionName"));
    const script_id = session_mod.str(frame.get("scriptId"));
    const url = session_mod.str(frame.get("url"));
    const line = jsonNumber(frame.get("lineNumber"));
    const col = jsonNumber(frame.get("columnNumber"));

    if (findScriptIndex(state, script_id, url, line, col)) |idx| {
        const script = &state.scripts.items[idx];
        switch (script.map_state) {
            .loaded => |sm| {
                const rel = script.rawToRelative(line, col);
                if (sm.findEntry(rel.line, rel.column)) |entry| {
                    if (entry.source_url) |src_url| {
                        if (state.isActiveSourceMap(idx, src_url) and entry.source_line >= 0 and entry.source_column >= 0) {
                            if (sm.hasIgnoreListHint(src_url)) return null;
                            return try std.fmt.allocPrint(
                                arena,
                                "at {s} ({s}:{d}:{d})",
                                .{ name, try console.displayName(arena, src_url), entry.source_line + 1, entry.source_column + 1 },
                            );
                        }
                    }
                }
            },
            else => {},
        }
    }

    if (url.len == 0) {
        return try std.fmt.allocPrint(arena, "at {s} (VM{s}:{d}:{d})", .{ name, script_id, line + 1, col + 1 });
    }
    return try std.fmt.allocPrint(arena, "at {s} ({s}:{d}:{d})", .{ name, try console.displayName(arena, url), line + 1, col + 1 });
}

fn jsonNumber(value: ?std.json.Value) i64 {
    const v = value orelse return 0;
    return switch (v) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => 0,
    };
}

test "console stack trace source-map resolution and ignoreList filtering" {
    const alloc = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(alloc);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const map_json =
        \\{"version":3,"sources":["vendor.js","src/app.ts"],"ignoreList":[0],"names":[],"mappings":"AAAS;ACgCI"}
    ;
    const sm = try lp.source_map.parse(alloc, "http://example.test/bundle.js", "http://example.test/bundle.js.map", map_json);
    var state: lp.State = .{};
    defer state.deinit(alloc);
    try state.scripts.append(alloc, .{
        .id = try alloc.dupe(u8, "42"),
        .url = try alloc.dupe(u8, "http://example.test/bundle.js"),
        .source_map_url = try alloc.dupe(u8, "bundle.js.map"),
        .has_source_url = true,
        .has_syntax_error = false,
        .start_line = 0,
        .start_column = 0,
        .end_line = 10,
        .end_column = 0,
        .context_id = 1,
        .parse_order = 1,
        .map_state = .{ .loaded = sm },
    });

    const stack =
        \\{"callFrames":[{"functionName":"lib","scriptId":"42","url":"http://example.test/bundle.js","lineNumber":0,"columnNumber":15},{"functionName":"app","scriptId":"42","url":"http://example.test/bundle.js","lineNumber":1,"columnNumber":10}]}
    ;
    const formatted = try formatStackTraceWithState(arena, &state, stack, &.{}, true);
    try std.testing.expectEqualStrings(
        "at app (app.ts:42:5)\nNote: line and column numbers use 1-based indexing",
        formatted,
    );
}

pub fn pageSize(args: std.json.ObjectMap) ?usize {
    const v = registry.numberArg(args, "pageSize") orelse return null;
    return @intFromFloat(@max(1, v));
}

pub fn pageIdx(args: std.json.ObjectMap) ?i64 {
    const v = registry.numberArg(args, "pageIdx") orelse return null;
    return @intFromFloat(v);
}

pub const Shown = struct { start: usize, end: usize };

/// paginate + #dataWithPagination's info lines (appended to `lines`).
pub fn paginate(arena: Allocator, total: usize, page_size: ?usize, page_idx: ?i64, lines: *std.ArrayList([]const u8)) !Shown {
    // pagination is set only with a pageSize (setIncludeConsoleData).
    const size = page_size orelse {
        try lines.append(arena, try std.fmt.allocPrint(arena, "Showing {d}-{d} of {d} (Page 1 of 1).", .{ if (total == 0) @as(usize, 0) else 1, total, total }));
        return .{ .start = 0, .end = total };
    };
    const total_pages = @max(1, (total + size - 1) / size);
    var current: usize = 0;
    var invalid = false;
    if (page_idx) |idx| {
        if (idx < 0 or idx >= total_pages) invalid = true else current = @intCast(idx);
    }
    if (invalid) try lines.append(arena, "Invalid page number provided. Showing first page.");
    const start = current * size;
    const end = @min(total, start + size);
    try lines.append(arena, try std.fmt.allocPrint(arena, "Showing {d}-{d} of {d} (Page {d} of {d}).", .{ if (total == 0) @as(usize, 0) else start + 1, end, total, current + 1, total_pages }));
    if (current < total_pages - 1) try lines.append(arena, try std.fmt.allocPrint(arena, "Next page: {d}", .{current + 1}));
    if (current > 0) try lines.append(arena, try std.fmt.allocPrint(arena, "Previous page: {d}", .{current - 1}));
    return .{ .start = start, .end = end };
}
