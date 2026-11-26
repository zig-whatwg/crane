//! set_logpoints - chrome-devtools-mcp v1.13.0's src/tools/logpoints.ts and
//! LogpointManager.setLogpoints (Copyright 2026 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md), over the page's DevTools universe
//! (../logpoints.zig): every logpoint parsed, every expression compiled,
//! every location found (waiting up to 5 s for source maps and preferring a
//! source-mapped source at the served URL), before anything changes; then each
//! location normalized through `DebuggerWorkspaceBinding`, set or updated in
//! V8 (the last expression for a normalized location wins), a new one that V8
//! resolves nowhere removed and reported, and every logpoint not in the list
//! removed. Source maps are loaded lazily until logpoints exist, then eagerly
//! so reloads and rebuilt bundles re-resolve automatically.

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const str = session_mod.str;
const Response = @import("../response.zig").Response;
const lp = @import("../logpoints.zig");
const js_scopes = @import("../js_scopes.zig");

pub const list = [_]Tool{
    .{ .name = "set_logpoints", .page_tool = true, .run = setLogpoints },
};

const logged = "Logged output appears in list_console_messages once a line executes; objects show as [object Object] there, get_console_message shows them as JSON.";
const source_mapped_note = "Source-mapped locations are re-resolved automatically when a matching source map loads again (for example after a reload with a regenerated bundle). Note: on the first page load after a rebuild, code that runs during the load itself is not logged yet; if a load-time logpoint stays silent right after a rebuild, reload once more before concluding that the line does not run.";

/// Reap finished background source map loads, wait once for newly parsed
/// scripts' maps when source-mapped logpoints are active (eager mode after a
/// reload or rebuild), and re-bind any affected source-mapped logpoints.
pub fn syncSourceMaps(ctx: *Context, page: *Page) !void {
    const state = &page.logpoints;
    _ = state.pollLoads();
    if (state.lazy_loading or state.records.items.len == 0) return;
    const has_source_mapped = for (state.records.items) |r| {
        if (r.from_source_map) break true;
    } else false;
    if (has_source_mapped) {
        var need_wait = false;
        for (state.scripts.items) |*s| {
            if (s.source_map_url.len == 0 or s.has_syntax_error or s.eager_waited) continue;
            if (s.map_state == .none or s.map_state == .loading) {
                s.eager_waited = true;
                need_wait = true;
            }
        }
        if (need_wait) {
            _ = try state.waitForMaps(ctx.session, page, null);
        }
    }
    if (!state.rebind_needed) return;
    state.rebind_needed = false;
    const debugger_session = page.debugger_session_id orelse return;
    for (state.records.items) |record| {
        if (!record.from_source_map) continue;
        try updateInBackend(ctx, page, debugger_session, record);
    }
}

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

    // Reap any completed background source map loads before lookups.
    _ = state.pollLoads();

    // validateExpression, each.
    for (requests) |request| try validateExpression(ctx, target, request.expression);

    // #findUISourceCode, each; the last entry for a location wins, in the
    // place of the first.
    const Resolved = struct { key: []const u8, source: lp.UiSource, request: lp.Request };
    var resolved: std.ArrayList(Resolved) = .empty;
    for (requests) |request| {
        const source = try findSource(ctx, target, request.url);
        const key = try lp.locationKey(ctx.arena, source.url, request.line, request.column);
        const entry: Resolved = .{ .key = key, .source = source, .request = request };
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
        // BreakpointManager.setBreakpoint -> DebuggerWorkspaceBinding.normalizeUILocation:
        // moves a generated location covered by a source map to its original
        // source, and normalizes a mapped original line to its first mapped column.
        const norm = try state.normalizeUiLocation(ctx.arena, entry.source, line, asked_column);
        const existing = state.find(norm.url, norm.from_source_map, norm.line, norm.column);
        if (existing) |record| {
            if (!std.mem.eql(u8, record.expression, entry.request.expression)) {
                const expression = try allocator.dupe(u8, entry.request.expression);
                allocator.free(record.expression);
                record.expression = expression;
            }
            try updateInBackend(ctx, target, debugger_session, record);
            // An existing logpoint stays, bound or not (deduplicated in `kept`).
            const already_kept = for (kept.items) |k| {
                if (k == record) break true;
            } else false;
            if (!already_kept) try kept.append(ctx.arena, record);
            continue;
        }
        const record = try allocator.create(lp.Logpoint);
        record.* = .{
            .url = &.{},
            .from_source_map = norm.from_source_map,
            .line = norm.line,
            .column = norm.column,
            .expression = &.{},
        };
        errdefer record.destroy(allocator);
        record.url = try allocator.dupe(u8, norm.url);
        record.expression = try allocator.dupe(u8, entry.request.expression);
        try updateInBackend(ctx, target, debugger_session, record);
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

    // LogpointManager #setLazySourceMapLoading(this.#records.size === 0).
    state.lazy_loading = state.records.items.len == 0;
    state.rebind_needed = false;

    const listing = try lp.formatList(ctx.arena, state.records.items);
    if (unbound.items.len != 0) {
        // LogpointError: the resulting state, then the error.
        try response.line("{s}", .{listing});
        return ctx.fail("No executable code at {s} (for example a comment, type annotation or empty line, or a line not mapped to the generated script). Pick lines containing executable code. The other logpoints were applied.", .{try std.mem.join(ctx.arena, ", ", unbound.items)});
    }
    try response.line("{s}", .{listing});
    if (state.records.items.len == 0) return;
    const any_source_mapped = for (state.records.items) |r| {
        if (r.from_source_map) break true;
    } else false;
    if (any_source_mapped) try response.line("{s}", .{source_mapped_note});
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

/// LogpointManager.#findUISourceCode: matches a script or source-map source,
/// waiting up to 5 s for source maps when a served script has a sourceMapURL
/// (preferring a source-mapped source at the same URL) or when nothing matched
/// yet.
fn findSource(ctx: *Context, page: *Page, url: []const u8) !lp.UiSource {
    const state = &page.logpoints;
    var match = try matchSource(ctx, page, url);
    var timed_out = false;
    if (match != null and !match.?.from_source_map) {
        const matched_url = match.?.url;
        if (state.hasSourceMapUrl(matched_url)) {
            const outcome = try state.waitForMaps(ctx.session, page, matched_url);
            match = try matchSource(ctx, page, url);
            if (outcome == .timed_out and (match == null or !match.?.from_source_map)) {
                return ctx.fail("The source map of {s} was still loading after {d} seconds; retry.", .{ matched_url, state.timeoutSecondsLabel() });
            }
        }
    } else if (match == null) {
        const outcome = try state.waitForMaps(ctx.session, page, null);
        timed_out = outcome == .timed_out;
        match = try matchSource(ctx, page, url);
    }
    if (match) |m| return m;

    // Sources with the same file name, at most five.
    const sources = try state.uiSources(ctx.arena, page.url);
    const name = try lp.baseName(ctx.arena, url);
    var similar: std.ArrayList([]const u8) = .empty;
    for (sources) |candidate| {
        if (similar.items.len == 5) break;
        if (std.mem.eql(u8, try lp.baseName(ctx.arena, candidate.url), name)) try similar.append(ctx.arena, candidate.url);
    }
    const timeout_note = if (timed_out)
        try std.fmt.allocPrint(ctx.arena, " Some source maps were still loading after {d} seconds; retry if the file comes from a source map.", .{state.timeoutSecondsLabel()})
    else
        "";
    const hint = if (similar.items.len != 0)
        try std.fmt.allocPrint(ctx.arena, " Sources with the same file name: {s}.", .{try std.mem.join(ctx.arena, ", ", similar.items)})
    else
        "";
    return ctx.fail("No parsed script or original source file matches \"{s}\". The url must match the URL of a script as served to the browser or an original source file from a source map, exactly or as a path suffix.{s}{s}", .{ url, timeout_note, hint });
}

/// LogpointManager.#matchUISourceCode: exact URL wins; otherwise unique path
/// suffix (`/<url>`); when both a served script and a source-mapped original
/// source share the same URL, the source-mapped source wins.
fn matchSource(ctx: *Context, page: *Page, url: []const u8) !?lp.UiSource {
    const sources = try page.logpoints.uiSources(ctx.arena, page.url);
    const suffix = try std.fmt.allocPrint(ctx.arena, "/{s}", .{url});
    var candidates: std.ArrayList(lp.UiSource) = .empty;
    for (sources) |candidate| {
        if (!std.mem.eql(u8, candidate.url, url) and !std.mem.endsWith(u8, candidate.url, suffix)) continue;
        const existing_idx: ?usize = for (candidates.items, 0..) |c, idx| {
            if (std.mem.eql(u8, c.url, candidate.url)) break idx;
        } else null;
        if (existing_idx) |idx| {
            if (candidate.from_source_map) candidates.items[idx] = candidate;
        } else {
            try candidates.append(ctx.arena, candidate);
        }
    }
    for (candidates.items) |c| {
        if (std.mem.eql(u8, c.url, url)) return c;
    }
    if (candidates.items.len > 1) {
        const urls = try ctx.arena.alloc([]const u8, candidates.items.len);
        for (candidates.items, urls) |c, *u| u.* = c.url;
        return ctx.fail("\"{s}\" matches multiple sources: {s}. Specify a longer path.", .{ url, try std.mem.join(ctx.arena, ", ", urls) });
    }
    if (candidates.items.len == 1) return candidates.items[0];
    return null;
}

/// ModelBreakpoint.#updateInDebugger: computes backend positions via
/// `uiLocationToRawLocations` (falling back to `last_resolved_state` or the
/// breakpoint's own location), skips if already a subset of `current_state`,
/// otherwise resets existing backend breakpoints and sets the new ones.
fn updateInBackend(ctx: *Context, page: *Page, debugger_session: []const u8, record: *lp.Logpoint) !void {
    const allocator = ctx.session.allocator;
    const state = &page.logpoints;
    const condition = try lp.backendCondition(ctx.arena, record.expression);

    const raw_locations = try state.uiLocationToRawLocations(
        ctx.arena,
        .{ .url = record.url, .from_source_map = record.from_source_map },
        record.line,
        record.column orelse 0,
    );

    var new_state: std.ArrayList(lp.BackendPosition) = .empty;
    defer {
        for (new_state.items) |*p| p.deinit(allocator);
        new_state.deinit(allocator);
    }

    if (raw_locations.len > 0) {
        for (raw_locations) |loc| {
            const loc_condition = try substituteForRawLocation(ctx, debugger_session, state, loc, record.expression, condition);
            const u = try allocator.dupe(u8, loc.url);
            errdefer allocator.free(u);
            const cond = try allocator.dupe(u8, loc_condition);
            try new_state.append(allocator, .{ .url = u, .line = loc.line, .column = loc.column, .condition = cond });
        }
    } else if (record.last_resolved_state.items.len > 0) {
        for (record.last_resolved_state.items) |*pos| {
            const u = try allocator.dupe(u8, pos.url);
            errdefer allocator.free(u);
            const cond = try allocator.dupe(u8, condition);
            try new_state.append(allocator, .{ .url = u, .line = pos.line, .column = pos.column, .condition = cond });
        }
    } else {
        const u = try allocator.dupe(u8, record.url);
        errdefer allocator.free(u);
        const cond = try allocator.dupe(u8, condition);
        try new_state.append(allocator, .{ .url = u, .line = record.line, .column = record.column, .condition = cond });
    }

    if (record.breakpoint_ids.items.len > 0 and lp.stateSubset(new_state.items, record.current_state.items)) {
        return;
    }

    // Update Breakpoint.#lastResolvedState.
    record.clearLastResolvedState(allocator);
    for (new_state.items) |*pos| {
        try record.last_resolved_state.append(allocator, try pos.dupe(allocator));
    }

    if (record.breakpoint_ids.items.len > 0) {
        try removeFromBackend(ctx, debugger_session, record);
    }

    // ModelBreakpoint.#setBreakpointOnBackend.
    for (new_state.items) |*pos| {
        var params: std.Io.Writer.Allocating = .init(ctx.arena);
        try params.writer.print("{{\"lineNumber\":{d},\"url\":{f}", .{ pos.line, std.json.fmt(pos.url, .{}) });
        if (pos.column) |c| try params.writer.print(",\"columnNumber\":{d}", .{c});
        try params.writer.print(",\"condition\":{f}}}", .{std.json.fmt(pos.condition, .{})});
        var r = try ctx.session.client.call("Debugger.setBreakpointByUrl", params.written(), debugger_session, session_mod.command_timeout_ms);
        defer r.deinit();
        const result = r.result() orelse continue;
        const id = str(result.object.get("breakpointId"));
        if (id.len == 0) continue;
        const bp_id = try allocator.dupe(u8, id);
        errdefer allocator.free(bp_id);
        try record.breakpoint_ids.append(allocator, bp_id);
        const locations = result.object.get("locations") orelse continue;
        if (locations != .array) continue;
        for (locations.array.items) |location| {
            if (location != .object) continue;
            const loc_bp = try allocator.dupe(u8, id);
            errdefer allocator.free(loc_bp);
            const script_id = try allocator.dupe(u8, str(location.object.get("scriptId")));
            errdefer allocator.free(script_id);
            try record.resolved.append(allocator, .{ .breakpoint_id = loc_bp, .script_id = script_id });
        }
    }

    record.clearCurrentState(allocator);
    for (new_state.items) |*pos| {
        try record.current_state.append(allocator, try pos.dupe(allocator));
    }
}

/// Breakpoint.backendCondition: when `loc`'s script has a loaded source map,
/// lazily fetches script source via `Debugger.getScriptSource` and substitutes
/// authored identifiers in `expression` to their minified generated names.
fn substituteForRawLocation(
    ctx: *Context,
    debugger_session: []const u8,
    state: *lp.State,
    loc: lp.RawLocation,
    expression: []const u8,
    default_condition: []const u8,
) ![]const u8 {
    if (loc.script_idx >= state.scripts.items.len) return default_condition;
    const script = &state.scripts.items[loc.script_idx];
    const sm = switch (script.map_state) {
        .loaded => |m| m,
        else => return default_condition,
    };
    const script_source = try ensureScriptSource(ctx, debugger_session, script) orelse return default_condition;
    const rel = script.rawToRelative(@intCast(loc.line), @intCast(loc.column));
    const substituted = try js_scopes.substituteAtLocation(ctx.arena, script_source, sm, rel.line, rel.column, expression);
    if (std.mem.eql(u8, substituted, expression)) return default_condition;
    return lp.backendCondition(ctx.arena, substituted);
}

fn ensureScriptSource(ctx: *Context, debugger_session: []const u8, script: *lp.Script) !?[]const u8 {
    if (script.source_fetched) return script.source;
    script.source_fetched = true;
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"scriptId\":{f}}}", .{std.json.fmt(script.id, .{})});
    var r = ctx.session.client.call("Debugger.getScriptSource", params, debugger_session, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    defer r.deinit();
    const result = r.result() orelse return null;
    const text = str(result.object.get("scriptSource"));
    if (text.len == 0) return null;
    script.source = try ctx.session.allocator.dupe(u8, text);
    return script.source;
}

/// ModelBreakpoint.resetBreakpoint: Debugger.removeBreakpoint for every backend id.
fn removeFromBackend(ctx: *Context, debugger_session: []const u8, record: *lp.Logpoint) !void {
    const allocator = ctx.session.allocator;
    record.clearResolved(allocator);
    record.clearCurrentState(allocator);
    while (record.breakpoint_ids.pop()) |id| {
        defer allocator.free(id);
        const params = try std.fmt.allocPrint(ctx.arena, "{{\"breakpointId\":{f}}}", .{std.json.fmt(id, .{})});
        var r = try ctx.session.client.call("Debugger.removeBreakpoint", params, debugger_session, session_mod.command_timeout_ms);
        r.deinit();
    }
}
