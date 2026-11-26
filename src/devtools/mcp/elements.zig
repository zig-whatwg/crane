//! A page's frames and the elements its snapshot's uids name:
//! chrome-devtools-mcp-v1.13.0's McpPage.getElementByUid (src/McpPage.ts),
//! and what it reaches through Puppeteer (puppeteer-core 25.17.0:
//! cdp/Accessibility.js AXNode.serialize's elementHandle,
//! cdp/IsolatedWorld.js adoptBackendNode) - the node by its backendNodeId
//! in its frame's main world, unless that frame has loaded another document
//! since; a text node stands for its parent element, or its shadow root's
//! host. Translated (Copyright 2025 Google LLC, Copyright 2018 Google Inc.;
//! Apache-2.0; THIRD_PARTY_NOTICES.md).

const std = @import("std");
const registry = @import("tools.zig");
const Context = registry.Context;
const session_mod = @import("session.zig");
const Page = session_mod.Page;
const str = session_mod.str;
const snapshot_mod = @import("snapshot.zig");

pub const Frame = struct {
    id: []const u8,
    /// The document it has now (Puppeteer's frame._loaderId).
    loader_id: []const u8,
};

/// The page's frames (Page.getFrameTree), the main frame first, each
/// before its children; in `ctx.arena`.
pub fn frames(ctx: *Context, page: *Page) ![]Frame {
    var r = try ctx.session.client.call("Page.getFrameTree", "{}", page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    var out: std.ArrayList(Frame) = .empty;
    const result = r.result() orelse return out.items;
    const tree = result.object.get("frameTree") orelse return out.items;
    try walk(ctx, tree, &out);
    return out.items;
}

fn walk(ctx: *Context, tree: std.json.Value, out: *std.ArrayList(Frame)) !void {
    if (tree != .object) return;
    const frame = tree.object.get("frame") orelse return;
    if (frame != .object) return;
    try out.append(ctx.arena, .{
        .id = try ctx.arena.dupe(u8, str(frame.object.get("id"))),
        .loader_id = try ctx.arena.dupe(u8, str(frame.object.get("loaderId"))),
    });
    const children = tree.object.get("childFrames") orelse return;
    if (children != .array) return;
    for (children.array.items) |child| try walk(ctx, child, out);
}

/// An element handle: its CallArgument and the remote object to release.
pub const Element = struct {
    /// The CallArgument's JSON (`{"objectId":...}`, or a value).
    argument: []const u8,
    /// Its remote object (null for a value), released by `release`.
    object_id: ?[]const u8,
    /// The frame it is in (Puppeteer's handle.frame).
    frame_id: []const u8,
};

/// Snapshot metadata for `uid` (copied into `ctx.arena`, safe across a
/// snapshot replacement). Fails with chrome-devtools-mcp's exact messages
/// when there is no snapshot or the uid is unknown.
pub fn targetByUid(ctx: *Context, page: *Page, uid: []const u8) !snapshot_mod.Target {
    const snapshot = page.text_snapshot orelse return ctx.fail("No snapshot found for page {d}. Use take_snapshot to capture one.", .{page.id});
    const target = snapshot.targets.get(uid) orelse return ctx.fail("Element uid \"{s}\" not found on page {d}.", .{ uid, page.id });
    const opts = try ctx.arena.alloc(snapshot_mod.OptionChild, target.options.len);
    for (target.options, opts) |o, *dst| {
        dst.* = .{
            .name = try ctx.arena.dupe(u8, o.name),
            .backend_node_id = o.backend_node_id,
            .loader_id = try ctx.arena.dupe(u8, o.loader_id),
            .frame_id = try ctx.arena.dupe(u8, o.frame_id),
        };
    }
    return .{
        .backend_node_id = target.backend_node_id,
        .loader_id = try ctx.arena.dupe(u8, target.loader_id),
        .frame_id = try ctx.arena.dupe(u8, target.frame_id),
        .role = try ctx.arena.dupe(u8, target.role),
        .options = opts,
    };
}

/// McpPage.getElementByUid: the tool fails with chrome-devtools-mcp's
/// messages when there is no snapshot, no such uid, or the node is gone.
pub fn byUid(ctx: *Context, page: *Page, uid: []const u8) !Element {
    const target = try targetByUid(ctx, page, uid);
    return resolve(ctx, page, target.backend_node_id, target.loader_id, target.frame_id) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => ctx.fail("Element with uid {s} no longer exists on the page.", .{uid}),
    };
}

/// Adopt a backend node (such as a combobox's `<option>` child) into its
/// frame's main world.
pub fn resolveNode(ctx: *Context, page: *Page, backend: i64, loader: []const u8, frame_id: []const u8) !Element {
    return resolve(ctx, page, backend, loader, frame_id);
}

/// elementHandle(): null (an error here) after a navigation, else the node
/// adopted into the frame's main world and mapped to its element.
fn resolve(ctx: *Context, page: *Page, backend: i64, loader: []const u8, frame_id: []const u8) !Element {
    const arena = ctx.arena;
    // After a navigation the backend node id can name another node.
    var current: ?[]const u8 = null;
    for (try frames(ctx, page)) |f| if (std.mem.eql(u8, f.id, frame_id)) {
        current = f.loader_id;
    };
    if (current == null or !std.mem.eql(u8, current.?, loader)) return error.Gone;
    const context_id = try mainWorld(ctx, page, frame_id);
    // adoptBackendNode.
    const resolve_params = try std.fmt.allocPrint(arena, "{{\"backendNodeId\":{d},\"executionContextId\":{d}}}", .{ backend, context_id });
    var resolved = try ctx.session.client.call("DOM.resolveNode", resolve_params, page.session_id, session_mod.command_timeout_ms);
    defer resolved.deinit();
    if (resolved.errorMessage() != null) return error.Gone;
    const object = (resolved.result() orelse return error.Gone).object.get("object") orelse return error.Gone;
    if (object != .object) return error.Gone;
    const node_id = try arena.dupe(u8, str(object.object.get("objectId")));
    if (node_id.len == 0) return error.Gone;
    defer release(ctx, page, node_id);
    // A text node's element (handle.evaluateHandle).
    const map_params = try std.fmt.allocPrint(arena, "{{\"functionDeclaration\":{f},\"executionContextId\":{d},\"arguments\":[{{\"objectId\":{f}}}],\"returnByValue\":false,\"awaitPromise\":true,\"userGesture\":true}}", .{ std.json.fmt(text_to_element, .{}), context_id, std.json.fmt(node_id, .{}) });
    var mapped = try ctx.session.client.call("Runtime.callFunctionOn", map_params, page.session_id, session_mod.command_timeout_ms);
    defer mapped.deinit();
    if (mapped.errorMessage() != null) return error.Gone;
    const result = mapped.result() orelse return error.Gone;
    if (result.object.get("exceptionDetails") != null) return error.Gone;
    const remote = result.object.get("result") orelse return error.Gone;
    if (remote != .object) return error.Gone;
    if (remote.object.get("objectId")) |id| if (id == .string) {
        const owned = try arena.dupe(u8, id.string);
        return .{ .argument = try std.fmt.allocPrint(arena, "{{\"objectId\":{f}}}", .{std.json.fmt(owned, .{})}), .object_id = owned, .frame_id = frame_id };
    };
    // A value (null: a text node with neither parent nor host).
    const value = remote.object.get("value") orelse std.json.Value.null;
    return .{ .argument = try std.fmt.allocPrint(arena, "{{\"value\":{f}}}", .{std.json.fmt(value, .{})}), .object_id = null, .frame_id = frame_id };
}

/// The function AXNode's elementHandle evaluates on the adopted node (its
/// compiled source, with Puppeteer's sourceURL).
const text_to_element =
    \\node => {
    \\                        if (node.nodeType !== Node.TEXT_NODE) {
    \\                            return node;
    \\                        }
    \\                        // A text node placed directly in a shadow root has no parent
    \\                        // element, so fall back to the shadow host.
    \\                        return (node.parentElement ??
    \\                            node.parentNode?.host ??
    \\                            null);
    \\                    }
    \\//# sourceURL=pptr:internal
    \\
;

/// The frame's main-world context, waited for as adoptBackendNode waits
/// (#waitForExecutionContext), up to the command timeout.
pub fn mainWorld(ctx: *Context, page: *Page, frame_id: []const u8) !i64 {
    const Ready = struct {
        page: *Page,
        frame_id: []const u8,
        fn done(self: @This()) bool {
            return self.page.closed or self.page.contextOf(self.frame_id, .main) != null;
        }
    };
    _ = try ctx.session.waitUntil(session_mod.command_timeout_ms, Ready{ .page = page, .frame_id = frame_id }, Ready.done);
    const context = page.contextOf(frame_id, .main) orelse return error.NoContext;
    return context.id;
}

/// A handle's dispose: Runtime.releaseObject, not waited for.
pub fn release(ctx: *Context, page: *Page, object_id: []const u8) void {
    const params = std.fmt.allocPrint(ctx.arena, "{{\"objectId\":{f}}}", .{std.json.fmt(object_id, .{})}) catch return;
    ctx.session.client.post("Runtime.releaseObject", params, page.session_id) catch {};
}
