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
    if (registry.stringArg(args, "serviceWorkerId") != null) return ctx.fail("Service worker not found.", .{});
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
                stack = try console.formatStackTrace(ctx.arena, t.stack_json, t.cause_lines, false);
                any_stack = true;
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
    if (id_value < 1 or id_value != @floor(id_value) or id_value > std.math.maxInt(u32)) return ctx.fail("Request not found for selected page", .{});
    const id: u32 = @intFromFloat(id_value);
    const message = target.console.byId(id) orelse return ctx.fail("Request not found for selected page", .{});
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
        if (symbolized.stack_json) |s| stack_text = try console.formatStackTrace(arena, s, try causeLines(arena, symbolized.cause), true);
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
        if (message.stack_json.len != 0) stack_text = try console.formatStackTrace(arena, message.stack_json, &.{}, true);
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
        return formatSymbolized(arena, symbolized);
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
    return .{ .stack_json = stack, .cause_lines = try causeLines(ctx.arena, symbolized.cause) };
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

/// formatCause's lines.
fn causeLines(arena: Allocator, cause: ?*Symbolized) ![]const []const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    var next = cause;
    while (next) |c| {
        try lines.append(arena, try std.fmt.allocPrint(arena, "Caused by: {s}", .{c.message}));
        if (c.stack_json) |s| try console.stackLines(arena, s, &lines);
        next = c.cause;
    }
    return lines.items;
}

/// formatArg of a SymbolizedError: its message, then its stack trace (with
/// the causes) when it has one.
fn formatSymbolized(arena: Allocator, symbolized: Symbolized) ![]const u8 {
    const stack = symbolized.stack_json orelse return symbolized.message;
    const trace = try console.formatStackTrace(arena, stack, try causeLines(arena, symbolized.cause), true);
    if (trace.len == 0) return symbolized.message;
    return std.fmt.allocPrint(arena, "{s}\n{s}", .{ symbolized.message, trace });
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
