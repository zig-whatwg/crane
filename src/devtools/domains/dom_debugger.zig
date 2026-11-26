//! The CDP `DOMDebugger` domain on page sessions (`DOMDebugger.getEventListeners`).
//!
//! Matches Blink `InspectorDOMDebuggerAgent::getEventListeners`,
//! `EventListenersInfoForTarget`, `CollectEventListeners`,
//! `BuildObjectsForEventListeners`, and `BuildObjectForEventListener`
//! (third_party/blink/renderer/core/inspector/inspector_dom_debugger_agent.cc;
//! traversal via `InspectorDOMAgent::CollectNodes` in
//! inspector_dom_agent.cc).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const PageSession = @import("../page_session.zig").PageSession;
const Reply = @import("../dispatch.zig").Reply;
const protocol = @import("../protocol/root.zig");
const frames = @import("../frames.zig");
const contexts = @import("../contexts.zig");
const dom_domain = @import("dom.zig");

const DD = protocol.DOMDebugger;

/// Per-session state of the DOMDebugger domain.
pub const State = struct {};

const have_inspector = contexts.have_inspector and
    @hasDecl(engine, "inspectorUnwrapWithGroup") and
    @hasDecl(engine, "inspectorFunctionLocation") and
    @hasDecl(engine, "inspectorWrap");

const CollectedListener = struct {
    event_type: []u8,
    use_capture: bool,
    passive: bool,
    once: bool,
    script_id: i32,
    line_number: i32,
    column_number: i32,
    handler_json: ?[]u8,
    original_handler_json: ?[]u8,
    backend_node_id: ?i64,

    fn deinit(self: CollectedListener, allocator: Allocator) void {
        allocator.free(self.event_type);
        if (self.handler_json) |j| allocator.free(j);
        if (self.original_handler_json) |j| allocator.free(j);
    }
};

/// `DOMDebugger.getEventListeners(objectId, depth, pierce)`: returns the event
/// listeners registered on `objectId` (and, for a Node, its descendants up to
/// `depth`, optionally piercing ShadowRoots and local iframes and reporting all
/// contexts when `pierce` is true).
pub fn getEventListeners(session: *PageSession, params: DD.getEventListeners.Params, reply: Reply(DD.getEventListeners)) !void {
    if (comptime have_inspector) return getEventListenersLive(session, params, reply);
    return session.fail("Could not find object with given id");
}

fn getEventListenersLive(session: *PageSession, params: DD.getEventListeners.Params, reply: Reply(DD.getEventListeners)) !void {
    const inspector = session.states.Runtime.inspector orelse return session.fail("Could not find object with given id");
    const allocator = session.allocator;

    const unwrapped = (engine.inspectorUnwrapWithGroup(inspector, params.objectId, allocator) catch
        return session.fail("Could not find object with given id")) orelse
        return session.fail("Could not find object with given id");
    defer unwrapped.deinit(allocator);

    const instance = engine.convertToPlatformObject(unwrapped.realm, unwrapped.value.borrow()) orelse {
        reply.okRaw("{\"listeners\":[]}");
        return;
    };

    var collected: std.ArrayListUnmanaged(CollectedListener) = .empty;
    defer {
        for (collected.items) |item| item.deinit(allocator);
        collected.deinit(allocator);
    }

    const object_group: ?[]const u8 = if (unwrapped.object_group) |g| (if (g.len > 0) g else null) else null;

    if (instance.implements(interfaces.Node.State)) {
        var depth = params.depth orelse 1;
        if (depth < 0) depth = std.math.maxInt(i64);
        const pierce = params.pierce orelse false;

        var nodes: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
        defer nodes.deinit(allocator);
        try collectNodes(session, allocator, instance, depth, pierce, &nodes);

        for (nodes.items) |node| {
            const backend_id = dom_domain.backendNodeIdFor(session, node);
            try collectEventListeners(
                inspector,
                allocator,
                node,
                backend_id,
                unwrapped.realm,
                object_group,
                pierce,
                &collected,
            );
        }
    } else if (instance.implements(interfaces.EventTarget.State)) {
        try collectEventListeners(
            inspector,
            allocator,
            instance,
            null,
            unwrapped.realm,
            object_group,
            false,
            &collected,
        );
    } else {
        reply.okRaw("{\"listeners\":[]}");
        return;
    }

    // Blink BuildObjectsForEventListeners: capture listeners first, then
    // non-capture listeners, preserving relative order within each pass.
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    const w = &out.writer;
    try w.writeAll("{\"listeners\":[");
    var first = true;
    for ([_]bool{ true, false }) |want_capture| {
        for (collected.items) |item| {
            if (item.use_capture != want_capture) continue;
            if (!first) try w.writeByte(',');
            first = false;
            try writeEventListenerJson(w, item);
        }
    }
    try w.writeAll("]}");
    reply.okRaw(out.written());
}

/// Blink `InspectorDOMAgent::CollectNodes`: visit `node`, decrement `depth`,
/// stop when `depth <= 0`; otherwise recurse into local iframe
/// `contentDocument` and `ShadowRoot` (when `pierce`) and light-DOM children.
fn collectNodes(
    session: *PageSession,
    allocator: Allocator,
    node: *runtime.Instance,
    depth_in: i64,
    pierce: bool,
    out: *std.ArrayListUnmanaged(*runtime.Instance),
) Allocator.Error!void {
    try out.append(allocator, node);
    const next_depth = depth_in - 1;
    if (next_depth <= 0) return;

    const node_type = interfaces.Node.get_nodeType(node) catch 0;
    if (pierce and node_type == 1) {
        if (contentDocumentOf(session, node)) |doc| {
            try collectNodes(session, allocator, doc, next_depth, pierce, out);
        }
        if (dom.shadow_hosts.rootForHost(node)) |shadow_root| {
            try collectNodes(session, allocator, shadow_root, next_depth, pierce, out);
        }
    }

    var child = interfaces.Node.get_firstChild(node) catch null;
    while (child) |c| {
        try collectNodes(session, allocator, c, next_depth, pierce, out);
        child = interfaces.Node.get_nextSibling(c) catch null;
    }
}

/// The active Document of a local frame owned by `element` (`<iframe>`, etc.),
/// if any, within `session`'s tab.
fn contentDocumentOf(session: *PageSession, element: *runtime.Instance) ?*runtime.Instance {
    const top = frames.navigable(session, session.tab) orelse return null;
    const child_bc = findByContainer(top, element) orelse return null;
    return frames.documentOf(child_bc);
}

fn findByContainer(bc: *frames.BrowsingContext, element: *runtime.Instance) ?*frames.BrowsingContext {
    for (bc.children.items) |child| {
        if (child.is_closed) continue;
        if (child.container) |container| {
            if (container == @as(*anyopaque, @ptrCast(element))) return child;
        }
        if (findByContainer(child, element)) |found| return found;
    }
    return null;
}

/// Blink `InspectorDOMDebuggerAgent::CollectEventListeners`.
fn collectEventListeners(
    inspector: *engine.InspectorSession,
    allocator: Allocator,
    target: *runtime.Instance,
    backend_node_id: ?i64,
    target_realm: runtime.Context,
    object_group: ?[]const u8,
    report_for_all_contexts: bool,
    out: *std.ArrayListUnmanaged(CollectedListener),
) Allocator.Error!void {
    const snap = try dom.event_listener_types.snapshotListeners(target, allocator);
    defer dom.event_listener_types.deinitSnapshot(allocator, snap);

    for (snap) |entry| {
        const listener_realm = entry.context orelse target.ctx;
        if (!report_for_all_contexts and listener_realm != target_realm) continue;

        const loc = (engine.inspectorFunctionLocation(listener_realm, entry.handler.borrow()) catch null) orelse continue;
        defer loc.deinit();

        var handler_json: ?[]u8 = null;
        errdefer if (handler_json) |j| allocator.free(j);
        var original_handler_json: ?[]u8 = null;
        errdefer if (original_handler_json) |j| allocator.free(j);

        if (object_group) |grp| {
            handler_json = engine.inspectorWrap(inspector, target_realm, loc.effective_function.borrow(), grp, allocator) catch null;
            original_handler_json = engine.inspectorWrap(inspector, target_realm, entry.handler.borrow(), grp, allocator) catch null;
        }

        const event_type = try allocator.dupe(u8, entry.event_type);
        errdefer allocator.free(event_type);

        try out.append(allocator, .{
            .event_type = event_type,
            .use_capture = entry.capture,
            .passive = entry.passive,
            .once = entry.once,
            .script_id = loc.script_id,
            .line_number = loc.line_number,
            .column_number = loc.column_number,
            .handler_json = handler_json,
            .original_handler_json = original_handler_json,
            .backend_node_id = backend_node_id,
        });
    }
}

fn writeEventListenerJson(w: *std.Io.Writer, item: CollectedListener) !void {
    try w.print(
        "{{\"type\":{f},\"useCapture\":{},\"passive\":{},\"once\":{},\"scriptId\":\"{d}\",\"lineNumber\":{d},\"columnNumber\":{d}",
        .{
            std.json.fmt(item.event_type, .{}),
            item.use_capture,
            item.passive,
            item.once,
            item.script_id,
            item.line_number,
            item.column_number,
        },
    );
    if (item.handler_json) |hj| {
        try w.writeAll(",\"handler\":");
        try w.writeAll(hj);
    }
    if (item.original_handler_json) |oj| {
        try w.writeAll(",\"originalHandler\":");
        try w.writeAll(oj);
    }
    if (item.backend_node_id) |bid| {
        try w.print(",\"backendNodeId\":{d}", .{bid});
    }
    try w.writeByte('}');
}
