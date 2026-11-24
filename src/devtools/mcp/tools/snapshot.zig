//! take_snapshot and wait_for - chrome-devtools-mcp's src/tools/snapshot.ts
//! (chrome-devtools-mcp-v1.13.0), with what they reach: McpResponse's
//! includeSnapshot, made in its handle (TextSnapshot.create over Puppeteer's
//! page.accessibility.snapshot({includeIframes: true, interestingOnly:
//! !verbose})), and McpPage.waitForTextOnPage (a race of `aria/<text>` and
//! `text/<text>` locators over the page's frames, those attached later
//! included). Translated (Copyright 2025 Google LLC, Apache-2.0;
//! puppeteer-core 25.17.0 cdp/Accessibility.js, Copyright 2018 Google Inc.,
//! Apache-2.0; THIRD_PARTY_NOTICES.md).
//!
//! Not yet: take_snapshot's `filePath` (the server's file access comes with
//! the path policy, batch 3) and wait_for's `visible` (whether text is
//! visible needs layout, which Crane does not have).

const std = @import("std");
const platform = @import("platform");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const str = session_mod.str;
const Response = @import("../response.zig").Response;
const snapshot = @import("../snapshot.zig");
const ax_tree = @import("../ax_tree.zig");
const elements = @import("../elements.zig");
const query = @import("../query.zig");
const console = @import("../console.zig");

pub const list = [_]Tool{
    .{ .name = "take_snapshot", .page_tool = true, .blocked_by_dialog = true, .run = takeSnapshot },
    .{ .name = "wait_for", .page_tool = true, .blocked_by_dialog = true, .run = waitFor },
};

fn takeSnapshot(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    if (registry.stringArg(args, "filePath") != null) return ctx.fail("filePath is not supported by Crane's MCP server yet.", .{});
    response.snapshot = try capture(ctx, page.?, registry.boolArg(args, "verbose") orelse false);
}

/// The Locator's own timeout: Locator.race makes a RaceLocator, whose
/// `_timeout` stays at Locator's 30000 unless wait_for passes one
/// (McpPage.waitForTextOnPage sets it only for a positive `timeout`).
const race_timeout_ms = 30_000;
/// RETRY_DELAY: how often a locator that has not matched tries again.
const retry_delay_ms = 100;

fn waitFor(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    // The schema made `text` a non-empty array of strings.
    const texts: []const std.json.Value = if (args.get("text")) |t| (if (t == .array) t.array.items else &.{}) else &.{};
    // timeoutSchema: zero or less is "the default".
    const timeout_ms: i64 = if (registry.numberArg(args, "timeout")) |t| (if (t > 0) @intFromFloat(t) else race_timeout_ms) else race_timeout_ms;
    if (registry.boolArg(args, "visible") orelse false) return ctx.fail("visible is not supported by Crane's MCP server: Crane has no layout to tell whether text is visible.", .{});
    const deadline = platform.monotonicMillis() + timeout_ms;
    while (!(try textOnPage(ctx, target, texts))) {
        if (platform.monotonicMillis() >= deadline) {
            return ctx.fail("Timed out after waiting {d}ms. Text matching is case-sensitive. DOM text must preserve spaces and newlines, whereas snapshot text may normalize whitespace. Try a shorter distinctive substring.", .{timeout_ms});
        }
        const retry_at = @min(deadline, platform.monotonicMillis() + retry_delay_ms);
        while (platform.monotonicMillis() < retry_at) _ = try ctx.session.client.pump(10 * std.time.ns_per_ms);
    }
    var listed: std.Io.Writer.Allocating = .init(ctx.arena);
    try console.jsonStringify(&listed.writer, args.get("text") orelse .null);
    try response.line("Element matching one of {s} found.", .{listed.written()});
    response.snapshot = try capture(ctx, target, false);
}

/// One round of the race: whether any frame has an element whose
/// accessible name is one of `texts` (the ignored ones and text-only roles
/// aside) or whose text contains one.
fn textOnPage(ctx: *Context, page: *Page, texts: []const std.json.Value) !bool {
    for (try elements.frames(ctx, page)) |frame| {
        const world = (try utilityWorld(ctx, page, frame.id)) orelse continue;
        for (texts) |text| {
            if (try ariaMatch(ctx, page, world.document, str(text))) return true;
            if (try textMatch(ctx, page, world.util, str(text))) return true;
        }
    }
    return false;
}

const Utility = struct {
    /// The injected object's and the document's remote objects (copies).
    util: []const u8,
    document: []const u8,
};

/// The frame's utility world (Puppeteer's PUPPETEER_WORLD, which it makes
/// in every frame), with the injected text query and the document in it;
/// made the first time a frame needs it. Null when the frame has none.
fn utilityWorld(ctx: *Context, page: *Page, frame_id: []const u8) !?Utility {
    if (page.contextOf(frame_id, .utility) == null) {
        const params = try std.fmt.allocPrint(ctx.arena, "{{\"frameId\":{f},\"worldName\":\"{s}\",\"grantUniveralAccess\":true}}", .{ std.json.fmt(frame_id, .{}), session_mod.utility_world_name });
        var r = ctx.session.client.call("Page.createIsolatedWorld", params, page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return null,
        };
        defer r.deinit();
        const result = r.result() orelse return null;
        const id = result.object.get("executionContextId") orelse return null;
        if (id != .integer) return null;
        try ctx.session.addContext(page, id.integer, frame_id, .utility);
    }
    const context_id = (page.contextOf(frame_id, .utility) orelse return null).id;
    if (page.contextOf(frame_id, .utility).?.util_object == null) {
        const util = (try objectIn(ctx, page, context_id, query.text_query_source)) orelse return null;
        // The context may have gone while the answer came.
        const context = page.contextOf(frame_id, .utility) orelse return null;
        if (context.id != context_id) return null;
        context.util_object = try ctx.session.allocator.dupe(u8, util);
    }
    if (page.contextOf(frame_id, .utility).?.document_object == null) {
        const document = (try objectIn(ctx, page, context_id, "document")) orelse return null;
        const context = page.contextOf(frame_id, .utility) orelse return null;
        if (context.id != context_id) return null;
        context.document_object = try ctx.session.allocator.dupe(u8, document);
    }
    const context = page.contextOf(frame_id, .utility).?;
    return .{
        .util = try ctx.arena.dupe(u8, context.util_object.?),
        .document = try ctx.arena.dupe(u8, context.document_object.?),
    };
}

/// Runtime.evaluate of `expression` in context `id`, by reference: the
/// result's remote object id (in `ctx.arena`), or null.
fn objectIn(ctx: *Context, page: *Page, id: i64, expression: []const u8) !?[]const u8 {
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"expression\":{f},\"contextId\":{d},\"returnByValue\":false,\"awaitPromise\":true}}", .{ std.json.fmt(expression, .{}), id });
    var r = ctx.session.client.call("Runtime.evaluate", params, page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    defer r.deinit();
    const result = r.result() orelse return null;
    if (result.object.get("exceptionDetails") != null) return null;
    const remote = result.object.get("result") orelse return null;
    if (remote != .object) return null;
    const object_id = str(remote.object.get("objectId"));
    if (object_id.len == 0) return null;
    return try ctx.arena.dupe(u8, object_id);
}

/// The `aria/<text>` locator's query (ARIAQueryHandler.queryOne over
/// ElementHandle.queryAXTree): Accessibility.queryAXTree on the document
/// for the selector's name and role; an answer that is neither ignored nor
/// role-less nor a text-only role matches. A selector Puppeteer rejects
/// never matches; a failed query is no match this round.
fn ariaMatch(ctx: *Context, page: *Page, document: []const u8, text: []const u8) !bool {
    const selector = (try query.parseAriaSelector(ctx.arena, text)) orelse return false;
    var params: std.Io.Writer.Allocating = .init(ctx.arena);
    try params.writer.print("{{\"objectId\":{f}", .{std.json.fmt(document, .{})});
    if (selector.name) |name| try params.writer.print(",\"accessibleName\":{f}", .{std.json.fmt(name, .{})});
    if (selector.role) |role| try params.writer.print(",\"role\":{f}", .{std.json.fmt(role, .{})});
    try params.writer.writeAll("}");
    var r = ctx.session.client.call("Accessibility.queryAXTree", params.written(), page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer r.deinit();
    const result = r.result() orelse return false;
    const nodes = result.object.get("nodes") orelse return false;
    if (nodes != .array) return false;
    for (nodes.array.items) |node| {
        if (node != .object) continue;
        if (node.object.get("ignored")) |ignored| if (ignored == .bool and ignored.bool) continue;
        const role = node.object.get("role") orelse continue;
        if (role != .object) continue;
        if (!query.isElementRole(str(role.object.get("value")))) continue;
        return true;
    }
    return false;
}

/// The `text/<text>` locator's query: the injected textQuerySelectorAll
/// from the document, in the utility world.
fn textMatch(ctx: *Context, page: *Page, util: []const u8, text: []const u8) !bool {
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"functionDeclaration\":{f},\"objectId\":{f},\"arguments\":[{{\"value\":{f}}}],\"returnByValue\":true,\"awaitPromise\":true}}", .{ std.json.fmt(query.text_query_call, .{}), std.json.fmt(util, .{}), std.json.fmt(text, .{}) });
    var r = ctx.session.client.call("Runtime.callFunctionOn", params, page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer r.deinit();
    const result = r.result() orelse return false;
    if (result.object.get("exceptionDetails") != null) return false;
    const remote = result.object.get("result") orelse return false;
    if (remote != .object) return false;
    const value = remote.object.get("value") orelse return false;
    return value == .bool and value.bool;
}

// ----------------------------------------------------------------------
// The snapshot (McpResponse.#handleSnapshot)
// ----------------------------------------------------------------------

/// TextSnapshot.create, then SnapshotFormatter.toString: the page's
/// snapshot, kept as the page's last (its uids), and its text. A failure is
/// McpResponse.handle's own: the tool's answer is the message alone.
pub fn capture(ctx: *Context, page: *Page, verbose: bool) ![]const u8 {
    const session = ctx.session;
    var answers: std.ArrayList(@import("../client.zig").Response) = .empty;
    defer {
        for (answers.items) |*a| a.deinit();
        answers.deinit(session.allocator);
    }
    const main_frame = try ctx.arena.dupe(u8, page.mainFrameId());
    const loaders = try elements.frames(ctx, page);
    const tree = (try frameTree(ctx, page, main_frame, loaders, &answers, true)) orelse
        return ctx.failPlain("Failed to create accessibility snapshot", .{});
    const root = (try snapshot.serializeRoot(ctx.arena, tree, verbose)) orelse
        return ctx.failPlain("Failed to create accessibility snapshot", .{});
    const snapshot_id = session.next_snapshot_id;
    session.next_snapshot_id += 1;
    var targets: std.StringArrayHashMapUnmanaged(snapshot.Target) = .empty;
    try snapshot.assignIds(ctx.arena, session.allocator, root, snapshot_id, &page.uids, &targets);
    const text = try snapshot.format(ctx.arena, root, verbose);
    // The page's snapshot now: its uids' nodes, copied out of this call.
    const kept = try session.allocator.create(session_mod.TextSnapshot);
    kept.* = .{ .arena = .init(session.allocator) };
    errdefer {
        kept.arena.deinit();
        session.allocator.destroy(kept);
    }
    const keep = kept.arena.allocator();
    var it = targets.iterator();
    while (it.next()) |e| try kept.targets.put(keep, try keep.dupe(u8, e.key_ptr.*), .{
        .backend_node_id = e.value_ptr.backend_node_id,
        .loader_id = try keep.dupe(u8, e.value_ptr.loader_id),
        .frame_id = try keep.dupe(u8, e.value_ptr.frame_id),
    });
    page.setSnapshot(session.allocator, kept);
    return text;
}

/// One frame's tree (Accessibility.getFullAXTree), each Iframe given its
/// content frame's tree (populateIframes: DOM.describeNode's frameId; an
/// iframe whose frame fails is left without, "frames can get detached at
/// any time"). A failure of the top frame's tree fails the snapshot.
fn frameTree(
    ctx: *Context,
    page: *Page,
    frame_id: []const u8,
    loaders: []const elements.Frame,
    answers: *std.ArrayList(@import("../client.zig").Response),
    top: bool,
) anyerror!?*ax_tree.AX {
    const session = ctx.session;
    const frame_copy = try ctx.arena.dupe(u8, frame_id);
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"frameId\":{f}}}", .{std.json.fmt(frame_copy, .{})});
    var r = try session.client.call("Accessibility.getFullAXTree", params, page.session_id, session_mod.command_timeout_ms);
    if (r.errorMessage()) |message| {
        defer r.deinit();
        if (!top) return error.FrameFailed;
        return ctx.failPlain("Protocol error (Accessibility.getFullAXTree): {s}", .{message});
    }
    answers.append(session.allocator, r) catch |err| {
        r.deinit();
        return err;
    };
    const result = r.result() orelse return null;
    const nodes = result.object.get("nodes") orelse return null;
    if (nodes != .array) return null;
    var loader: []const u8 = "";
    for (loaders) |f| if (std.mem.eql(u8, f.id, frame_copy)) {
        loader = f.loader_id;
    };
    const root = (try ax_tree.createTree(ctx.arena, nodes.array.items, loader, frame_copy)) orelse return null;
    var iframes: std.ArrayList(*ax_tree.AX) = .empty;
    try ax_tree.iframes(ctx.arena, root, &iframes);
    for (iframes.items) |iframe| {
        const backend = iframe.backendNodeId() orelse continue;
        const child_frame = (try contentFrame(ctx, page, backend)) orelse continue;
        iframe.frame_tree = frameTree(ctx, page, child_frame, loaders, answers, false) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => null,
        };
    }
    return root;
}

/// ElementHandle.contentFrame: the frame DOM.describeNode names for the
/// iframe element.
fn contentFrame(ctx: *Context, page: *Page, backend_node_id: i64) !?[]const u8 {
    const params = try std.fmt.allocPrint(ctx.arena, "{{\"backendNodeId\":{d}}}", .{backend_node_id});
    var r = ctx.session.client.call("DOM.describeNode", params, page.session_id, session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    defer r.deinit();
    const result = r.result() orelse return null;
    const node = result.object.get("node") orelse return null;
    if (node != .object) return null;
    const frame_id = node.object.get("frameId") orelse return null;
    if (frame_id != .string) return null;
    return try ctx.arena.dupe(u8, frame_id.string);
}
