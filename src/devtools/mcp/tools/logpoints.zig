//! set_logpoints - chrome-devtools-mcp v1.13.0's src/tools/logpoints.ts and
//! LogpointManager.setLogpoints (Copyright 2026 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md), over the page's DevTools universe
//! (../logpoints.zig): every logpoint parsed, every expression compiled,
//! every location found, before anything changes; then each location's
//! breakpoint set or updated - the last expression for a location wins - a
//! new one that V8 resolves nowhere removed and reported, and every logpoint
//! not in the list removed. Script URLs only (batch 4b item 3a): source maps
//! are item 3b.

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const str = session_mod.str;
const Response = @import("../response.zig").Response;
const lp = @import("../logpoints.zig");

pub const list = [_]Tool{
    .{ .name = "set_logpoints", .page_tool = true, .run = setLogpoints },
};

const logged = "Logged output appears in list_console_messages once a line executes; objects show as [object Object] there, get_console_message shows them as JSON.";

fn setLogpoints(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const items = (args.get("logpoints") orelse return ctx.fail("logpoints is required", .{})).array.items;
    // The handler's request.params.logpoints.map(parseLogpoint).
    const requests = try ctx.arena.alloc(lp.Request, items.len);
    for (items, requests) |item, *request| {
        const text = str(item);
        request.* = switch (lp.parse(text)) {
            .ok => |r| r,
            .invalid => return ctx.fail("Invalid logpoint \"{s}\". Expected the format " ++ lp.logpoint_format ++ ", for example \"src/app.ts:42 'total', cart.total\".", .{text}),
            .not_one_based => return ctx.fail("Invalid logpoint \"{s}\": line and column numbers are 1-based.", .{text}),
        };
    }
    const state = &target.logpoints;
    // McpPage.setLogpoints: the manager on first use, so an empty list on a
    // page without logpoints is a no-op.
    if (!state.manager) {
        if (requests.len == 0) return response.line("{s}", .{try lp.formatList(ctx.arena, &.{})});
        if (target.debugger_session_id == null) return ctx.fail("DevTools universe is not available for page {d}.", .{target.id});
        state.manager = true;
    }
    const debugger_session = target.debugger_session_id orelse return ctx.fail("DevTools universe is not available for page {d}.", .{target.id});

    // validateExpression, each.
    for (requests) |request| try validateExpression(ctx, target, request.expression);

    // #findUISourceCode, each; the last entry for a location wins, in the
    // place of the first.
    const Resolved = struct { key: []const u8, url: []const u8, request: lp.Request };
    var resolved: std.ArrayList(Resolved) = .empty;
    for (requests) |request| {
        const url = try findSource(ctx, target, request.url);
        const key = try lp.locationKey(ctx.arena, url, request.line, request.column);
        const entry: Resolved = .{ .key = key, .url = url, .request = request };
        const replaced = for (resolved.items) |*r| {
            if (std.mem.eql(u8, r.key, key)) {
                r.* = entry;
                break true;
            }
        } else false;
        if (!replaced) try resolved.append(ctx.arena, entry);
    }

    const allocator = ctx.session.allocator;
    var kept: std.ArrayList(*lp.Logpoint) = .empty;
    var unbound: std.ArrayList([]const u8) = .empty;
    for (resolved.items) |entry| {
        const line = entry.request.line - 1;
        const asked_column: ?u64 = if (entry.request.column) |c| c - 1 else null;
        // normalizeUILocation: a location in a script's source is a raw
        // location, whose column is 0 when none was asked for.
        const column: ?u64 = if (state.hasScript(entry.url)) asked_column orelse 0 else asked_column;
        const existing = state.find(entry.url, line, column);
        if (existing) |record| {
            if (!std.mem.eql(u8, record.expression, entry.request.expression)) {
                // Breakpoint.updateState: the ModelBreakpoint's backend
                // breakpoint removed, then set with the new condition.
                const expression = try allocator.dupe(u8, entry.request.expression);
                allocator.free(record.expression);
                record.expression = expression;
                try removeFromBackend(ctx, debugger_session, record);
                try setInBackend(ctx, debugger_session, record);
            }
            // An existing logpoint stays, bound or not.
            try kept.append(ctx.arena, record);
            continue;
        }
        const record = try allocator.create(lp.Logpoint);
        record.* = .{ .url = &.{}, .line = line, .column = column, .expression = &.{} };
        errdefer record.destroy(allocator);
        record.url = try allocator.dupe(u8, entry.url);
        record.expression = try allocator.dupe(u8, entry.request.expression);
        try setInBackend(ctx, debugger_session, record);
        // A new logpoint V8 resolved nowhere: removed, and reported.
        if (!record.bound()) {
            try unbound.append(ctx.arena, entry.key);
            try removeFromBackend(ctx, debugger_session, record);
            // Nothing can fail after it: the errdefer above must not run.
            record.destroy(allocator);
            continue;
        }
        // Kept first: once the page's list holds it, it is freed with it.
        try kept.append(ctx.arena, record);
        try state.records.append(allocator, record);
    }
    // Every other logpoint: removed.
    var i: usize = 0;
    while (i < state.records.items.len) {
        const record = state.records.items[i];
        const is_kept = for (kept.items) |k| {
            if (k == record) break true;
        } else false;
        if (is_kept) {
            i += 1;
            continue;
        }
        _ = state.records.orderedRemove(i);
        defer record.destroy(allocator);
        try removeFromBackend(ctx, debugger_session, record);
    }

    const listing = try lp.formatList(ctx.arena, state.records.items);
    if (unbound.items.len != 0) {
        // LogpointError: the resulting state, then the error.
        try response.line("{s}", .{listing});
        return ctx.fail("No executable code at {s} (for example a comment, type annotation or empty line, or a line not mapped to the generated script). Pick lines containing executable code. The other logpoints were applied.", .{try std.mem.join(ctx.arena, ", ", unbound.items)});
    }
    try response.line("{s}", .{listing});
    if (state.records.items.len == 0) return;
    try response.line("{s}", .{logged});
}

/// validateExpression: `console.log(<expression>)` compiled, never run.
/// Google's server compiles it with Node's V8 (vm.Script); Crane's server
/// asks the page's (Runtime.compileScript, not persisted): the same parser,
/// the same message.
fn validateExpression(ctx: *Context, page: *Page, expression: []const u8) !void {
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"expression\":{f},\"sourceURL\":\"\",\"persistScript\":false}}", .{std.json.fmt(try std.fmt.allocPrint(ctx.arena, "console.log({s})", .{expression}), .{})});
    var r = ctx.session.client.call("Runtime.compileScript", params, page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return,
    };
    defer r.deinit();
    const result = r.result() orelse return;
    const details = result.object.get("exceptionDetails") orelse return;
    if (details != .object) return;
    return ctx.fail("The logpoint expression `{s}` does not compile: {s}. Provide the expression like arguments to console.log(...).", .{ expression, try errorMessage(ctx.arena, details.object) });
}

/// A thrown error's `message` from its exception details: the
/// description's first line after "<className>: ".
fn errorMessage(arena: std.mem.Allocator, details: std.json.ObjectMap) ![]const u8 {
    const exception = details.get("exception") orelse return arena.dupe(u8, str(details.get("text")));
    if (exception != .object) return arena.dupe(u8, str(details.get("text")));
    const description = str(exception.object.get("description"));
    const first = description[0 .. std.mem.indexOfScalar(u8, description, '\n') orelse description.len];
    const class_name = str(exception.object.get("className"));
    if (class_name.len != 0 and std.mem.startsWith(u8, first, class_name) and std.mem.startsWith(u8, first[class_name.len..], ": ")) return first[class_name.len + 2 ..];
    return first;
}

/// #findUISourceCode / #matchUISourceCode: the source whose URL is `url`,
/// or ends in "/" and `url`; an ambiguous suffix and no match are errors.
fn findSource(ctx: *Context, page: *Page, url: []const u8) ![]const u8 {
    const sources = try page.logpoints.sourceUrls(ctx.arena, page.url);
    var candidates: std.ArrayList([]const u8) = .empty;
    const suffix = try std.fmt.allocPrint(ctx.arena, "/{s}", .{url});
    for (sources) |candidate| {
        if (std.mem.eql(u8, candidate, url)) return candidate;
        if (std.mem.endsWith(u8, candidate, suffix)) try candidates.append(ctx.arena, candidate);
    }
    if (candidates.items.len > 1) return ctx.fail("\"{s}\" matches multiple sources: {s}. Specify a longer path.", .{ url, try std.mem.join(ctx.arena, ", ", candidates.items) });
    if (candidates.items.len == 1) return candidates.items[0];
    // Sources with the same file name, at most five.
    const name = try lp.baseName(ctx.arena, url);
    var similar: std.ArrayList([]const u8) = .empty;
    for (sources) |candidate| {
        if (similar.items.len == 5) break;
        if (std.mem.eql(u8, try lp.baseName(ctx.arena, candidate), name)) try similar.append(ctx.arena, candidate);
    }
    const hint = if (similar.items.len != 0) try std.fmt.allocPrint(ctx.arena, " Sources with the same file name: {s}.", .{try std.mem.join(ctx.arena, ", ", similar.items)}) else "";
    return ctx.fail("No parsed script or original source file matches \"{s}\". The url must match the URL of a script as served to the browser or an original source file from a source map, exactly or as a path suffix.{s}", .{ url, hint });
}

/// ModelBreakpoint's #setBreakpointOnBackend: Debugger.setBreakpointByUrl
/// with the logpoint's condition; its locations are where it is bound.
fn setInBackend(ctx: *Context, debugger_session: []const u8, record: *lp.Logpoint) !void {
    const allocator = ctx.session.allocator;
    var params: std.Io.Writer.Allocating = .init(ctx.arena);
    try params.writer.print("{{\"lineNumber\":{d},\"url\":{f}", .{ record.line, std.json.fmt(record.url, .{}) });
    if (record.column) |c| try params.writer.print(",\"columnNumber\":{d}", .{c});
    try params.writer.print(",\"condition\":{f}}}", .{std.json.fmt(try lp.backendCondition(ctx.arena, record.expression), .{})});
    var r = try ctx.session.client.call("Debugger.setBreakpointByUrl", params.written(), debugger_session, session_mod.command_timeout_ms);
    defer r.deinit();
    const result = r.result() orelse return;
    const id = str(result.object.get("breakpointId"));
    if (id.len == 0) return;
    record.breakpoint_id = try allocator.dupe(u8, id);
    const locations = result.object.get("locations") orelse return;
    if (locations != .array) return;
    for (locations.array.items) |location| {
        if (location != .object) continue;
        const script_id = try allocator.dupe(u8, str(location.object.get("scriptId")));
        errdefer allocator.free(script_id);
        try record.resolved.append(allocator, script_id);
    }
}

/// ModelBreakpoint.resetBreakpoint: Debugger.removeBreakpoint.
fn removeFromBackend(ctx: *Context, debugger_session: []const u8, record: *lp.Logpoint) !void {
    const allocator = ctx.session.allocator;
    record.clearResolved(allocator);
    const id = record.breakpoint_id orelse return;
    record.breakpoint_id = null;
    defer allocator.free(id);
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"breakpointId\":{f}}}", .{std.json.fmt(id, .{})});
    var r = try ctx.session.client.call("Debugger.removeBreakpoint", params, debugger_session, session_mod.command_timeout_ms);
    r.deinit();
}
