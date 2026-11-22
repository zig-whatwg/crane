//! The DOM domain on page sessions: the part-1 commands the runners call
//! (lane cdph, P4; design 1.4 and 3.6) - node ids (backendNodeId,
//! node_ids.zig), describeNode, resolveNode, getFrameOwner, and the geometry
//! reads answered from the platform's layout (none without a renderer:
//! Chrome's messages for a node with no layout object). Both runners move
//! every element handle between worlds by describeNode {objectId} ->
//! backendNodeId -> resolveNode {backendNodeId, executionContextId}
//! (Puppeteer's and Playwright's adoption; 1,229 round trips in Vue's e2e).
//! Blink's InspectorDOMAgent (third_party/blink/renderer/core/inspector/
//! inspector_dom_agent.cc: describeNode, resolveNode, getFrameOwner,
//! BuildObjectForNode; reproduced, not copied). getDocument and the
//! nodeId-based tree are part 2: `nodeId` is 0 in every Node, as Chrome
//! gives it to a client that has not asked for the document.

const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const platform = @import("platform");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const Reply = @import("../dispatch.zig").Reply;
const frames = @import("../frames.zig");
const contexts = @import("../contexts.zig");
const NodeIds = @import("../node_ids.zig").NodeIds;
const D = protocol.DOM;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
};

pub fn enable(session: *PageSession, params: D.enable.Params) !D.enable.Result {
    _ = params;
    session.states.DOM.enabled = true;
    return .{};
}

pub fn disable(session: *PageSession, params: D.disable.Params) !D.disable.Result {
    _ = params;
    session.states.DOM.enabled = false;
    return .{};
}

/// The Browser's node ids.
fn nodeIds(session: *PageSession) ?*NodeIds {
    const browser = session.browser orelse return null;
    return browser.scope.of(NodeIds) catch null;
}

/// Whether the engine has the inspector's remote objects (lane cdpw).
const have_remote_objects = contexts.have_inspector and @hasDecl(engine, "inspectorUnwrap") and @hasDecl(engine, "inspectorWrap");

/// The node a command names: by backendNodeId, or by a remote object's id
/// (unwrapped by the session's inspector session). error.Protocol with
/// Chrome's message otherwise.
fn nodeNamed(session: *PageSession, backend_node_id: ?i64, object_id: ?[]const u8) !*runtime.Instance {
    if (backend_node_id) |id| {
        const ids = nodeIds(session) orelse return session.fail("No node with given id found");
        return ids.nodeOf(id) orelse session.fail("No node with given id found");
    }
    if (object_id) |id| {
        if (comptime !have_remote_objects) return session.fail("Could not find node with given id");
        const inspector = session.states.Runtime.inspector orelse return session.fail("Could not find node with given id");
        const unwrapped = (engine.inspectorUnwrap(inspector, id) catch null) orelse return session.fail("Could not find node with given id");
        defer unwrapped.value.release();
        const instance = engine.convertToPlatformObject(unwrapped.realm, unwrapped.value.borrow()) orelse return session.fail("Object id doesn't reference a Node");
        if (!instance.implements(interfaces.Node.State)) return session.fail("Object id doesn't reference a Node");
        return instance;
    }
    return session.fail("Either nodeId, backendNodeId or objectId must be specified");
}

/// Describe a node (InspectorDOMAgent::describeNode): its kind, names and
/// value, child count and attributes, to `depth` levels of children (1 by
/// default; -1 for all), with no nodeId (0).
pub fn describeNode(session: *PageSession, params: D.describeNode.Params, reply: Reply(D.describeNode)) !void {
    if (params.nodeId) |id| if (id != 0) return session.fail("Could not find node with given id");
    const node = try nodeNamed(session, params.backendNodeId, params.objectId);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const depth = params.depth orelse 1;
    const described = try buildNode(session, arena_state.allocator(), node, depth, params.pierce orelse false);
    reply.ok(.{ .node = described });
}

/// Blink's BuildObjectForNode, as describeNode uses it.
fn buildNode(session: *PageSession, arena: Allocator, node: *runtime.Instance, depth: i64, pierce: bool) !D.Node {
    const ids = nodeIds(session) orelse return error.OutOfMemory;
    const node_type = interfaces.Node.get_nodeType(node) catch 0;
    var name = interfaces.Node.get_nodeName(node) catch runtime.DOMString.initEmpty();
    defer name.deinit(node.ctx.allocator);
    var described: D.Node = .{
        .nodeId = 0,
        .backendNodeId = try ids.idOf(node),
        .nodeType = node_type,
        .nodeName = try arena.dupe(u8, name.asSlice()),
        .localName = "",
        .nodeValue = "",
    };
    switch (node_type) {
        // ELEMENT_NODE
        1 => {
            var local = interfaces.Element.get_localName(node) catch runtime.DOMString.initEmpty();
            defer local.deinit(node.ctx.allocator);
            described.localName = try arena.dupe(u8, local.asSlice());
            described.attributes = try attributesOf(arena, node);
            // A frame owner: its content frame (and, piercing, its document).
            if (contentNavigableOf(session, node)) |bc| {
                described.frameId = try arena.dupe(u8, session.frameId(bc.id).slice());
                if (pierce and depth != 0) {
                    if (frames.documentOf(bc)) |document| {
                        const content = try arena.create(D.Node);
                        content.* = try buildNode(session, arena, document, depth - 1, pierce);
                        described.contentDocument = content;
                    }
                }
            }
        },
        // TEXT, CDATA_SECTION, PROCESSING_INSTRUCTION, COMMENT
        3, 4, 7, 8 => {
            if (interfaces.Node.get_nodeValue(node) catch null) |value| {
                var v = value;
                defer v.deinit(node.ctx.allocator);
                described.nodeValue = try arena.dupe(u8, v.asSlice());
            }
        },
        // DOCUMENT_NODE
        9 => {
            const url = interfaces.Document.get_URL(node) catch "";
            defer if (url.len > 0) node.ctx.allocator.free(url);
            described.documentURL = try arena.dupe(u8, url);
            const base = interfaces.Node.get_baseURI(node) catch "";
            defer if (base.len > 0) node.ctx.allocator.free(base);
            described.baseURL = try arena.dupe(u8, base);
            described.xmlVersion = "";
            if (frameOfDocument(session, node)) |bc| described.frameId = try arena.dupe(u8, session.frameId(bc.id).slice());
        },
        else => {},
    }
    // Containers: how many children, and the children to `depth`.
    if (node_type == 1 or node_type == 9 or node_type == 11) {
        var count: i64 = 0;
        var child = interfaces.Node.get_firstChild(node) catch null;
        while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) count += 1;
        described.childNodeCount = count;
        if (depth != 0 and count > 0) {
            var children: std.ArrayListUnmanaged(D.Node) = .empty;
            child = interfaces.Node.get_firstChild(node) catch null;
            while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) {
                try children.append(arena, try buildNode(session, arena, c, if (depth > 0) depth - 1 else depth, pierce));
            }
            described.children = children.items;
        }
    }
    return described;
}

/// An element's attributes, flattened [name, value, ...] in order.
fn attributesOf(arena: Allocator, element: *runtime.Instance) !?[]const []const u8 {
    const attributes = interfaces.Element.get_attributes(element) catch return null;
    const length = interfaces.NamedNodeMap.get_length(attributes) catch 0;
    if (length == 0) return &.{};
    var out: std.ArrayListUnmanaged([]const u8) = .empty;
    var i: u32 = 0;
    while (i < length) : (i += 1) {
        const attr = (interfaces.NamedNodeMap.call_item(attributes, i) catch null) orelse continue;
        var name = interfaces.Attr.get_name(attr) catch continue;
        defer name.deinit(attr.ctx.allocator);
        var value = interfaces.Attr.get_value(attr) catch continue;
        defer value.deinit(attr.ctx.allocator);
        try out.append(arena, try arena.dupe(u8, name.asSlice()));
        try out.append(arena, try arena.dupe(u8, value.asSlice()));
    }
    return out.items;
}

/// The content navigable of a frame owner element (an iframe's), in the
/// session's tab.
fn contentNavigableOf(session: *PageSession, element: *runtime.Instance) ?*frames.BrowsingContext {
    const top = frames.navigable(session, session.tab) orelse return null;
    return findByContainer(top, element);
}

fn findByContainer(bc: *frames.BrowsingContext, element: *runtime.Instance) ?*frames.BrowsingContext {
    for (bc.children.items) |child| {
        if (child.is_closed) continue;
        if (child.container) |container| if (container == @as(*anyopaque, @ptrCast(element))) return child;
        if (findByContainer(child, element)) |found| return found;
    }
    return null;
}

/// The navigable whose active document `document` is, in the session's tab.
fn frameOfDocument(session: *PageSession, document: *runtime.Instance) ?*frames.BrowsingContext {
    const top = frames.navigable(session, session.tab) orelse return null;
    return findByDocument(top, document);
}

fn findByDocument(bc: *frames.BrowsingContext, document: *runtime.Instance) ?*frames.BrowsingContext {
    if (bc.getActiveDocument()) |active| if (active == @as(*anyopaque, @ptrCast(document))) return bc;
    for (bc.children.items) |child| {
        if (child.is_closed) continue;
        if (findByDocument(child, document)) |found| return found;
    }
    return null;
}

/// A remote object for the node, in the realm of execution context
/// `executionContextId` - a world's realm adopts the node there with that
/// world's wrapper (InspectorDOMAgent::resolveNode ->
/// V8InspectorSession::wrapObject in the context's script state).
pub fn resolveNode(session: *PageSession, params: D.resolveNode.Params, reply: Reply(D.resolveNode)) !void {
    if (params.nodeId) |id| if (id != 0) return session.fail("No node with given id found");
    const node = try nodeNamed(session, params.backendNodeId, null);
    if (comptime !have_remote_objects) return session.fail("Node with given id does not belong to the document");
    const inspector = session.states.Runtime.inspector orelse return session.fail("Node with given id does not belong to the document");
    const realm: runtime.Context = if (params.executionContextId) |context_id| blk: {
        const browser = session.browser orelse return session.fail("Cannot find context with specified id");
        const agent = browser.agent orelse return session.fail("Cannot find context with specified id");
        break :blk engine.inspectorRealmOfContextId(agent, context_id) orelse return session.fail("Cannot find context with specified id");
    } else node.ctx;
    const json = engine.inspectorWrap(inspector, realm, .{ .instance = node }, params.objectGroup orelse "", session.allocator) catch
        return session.fail("Node with given id does not belong to the document");
    defer session.allocator.free(json);
    var result: std.Io.Writer.Allocating = .init(session.allocator);
    defer result.deinit();
    try result.writer.print("{{\"object\":{s}}}", .{json});
    reply.okRaw(result.written());
}

/// The element that holds frame `frameId` (its container: an iframe).
pub fn getFrameOwner(session: *PageSession, params: D.getFrameOwner.Params) !D.getFrameOwner.Result {
    const bc = frames.frameNamed(session, params.frameId) orelse return session.fail("Frame with the given id was not found.");
    const container = bc.container orelse return session.fail("Frame with the given id does not belong to the target.");
    const element: *runtime.Instance = @ptrCast(@alignCast(container));
    const ids = nodeIds(session) orelse return error.OutOfMemory;
    return .{ .backendNodeId = try ids.idOf(element) };
}

/// The node's layout box from the platform (docs/platform-protocol.md 6.9);
/// null with none - always, without a renderer.
fn clientRectsOf(node: *runtime.Instance, arena: Allocator) ![]const platform.Rect {
    if (platform.capabilities.layout == .unsupported) {
        return &.{};
    } else {
        const browser = @import("html").platform_state.of(node.ctx) orelse return &.{};
        const document = interfaces.Node.get_ownerDocument(node) catch null;
        const document_node: platform.LayoutNode = .{ .id = if (document) |d| @intFromPtr(d) else 0 };
        return platform.clientRects(browser, document_node, .{ .id = @intFromPtr(node) }, arena);
    }
}

/// The node's border-box quads from the platform's layout; with no layout
/// box Chrome's "Could not compute content quads." (Playwright then reads
/// the element as not visible).
pub fn getContentQuads(session: *PageSession, params: D.getContentQuads.Params, reply: Reply(D.getContentQuads)) !void {
    const node = try nodeNamed(session, params.backendNodeId, params.objectId);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const rects = try clientRectsOf(node, arena);
    if (rects.len == 0) return session.fail("Could not compute content quads.");
    const quads = try arena.alloc(D.Quad, rects.len);
    for (rects, quads) |r, *q| {
        const points = try arena.alloc(f64, 8);
        points[0..8].* = .{ r.x, r.y, r.x + r.width, r.y, r.x + r.width, r.y + r.height, r.x, r.y + r.height };
        q.* = points;
    }
    reply.ok(.{ .quads = quads });
}

/// The node's box model; with no layout box Chrome's "Could not compute box
/// model."
pub fn getBoxModel(session: *PageSession, params: D.getBoxModel.Params, reply: Reply(D.getBoxModel)) !void {
    const node = try nodeNamed(session, params.backendNodeId, params.objectId);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const rects = try clientRectsOf(node, arena);
    if (rects.len == 0) return session.fail("Could not compute box model.");
    const r = rects[0];
    const quad = try arena.alloc(f64, 8);
    quad[0..8].* = .{ r.x, r.y, r.x + r.width, r.y, r.x + r.width, r.y + r.height, r.x, r.y + r.height };
    reply.ok(.{ .model = .{
        .content = quad,
        .padding = quad,
        .border = quad,
        .margin = quad,
        .width = @intFromFloat(@round(r.width)),
        .height = @intFromFloat(@round(r.height)),
    } });
}

/// Scroll the node into view through the platform's layout; with no layout
/// box Chrome's "Node does not have a layout object" (Puppeteer falls back to
/// element.scrollIntoView()).
pub fn scrollIntoViewIfNeeded(session: *PageSession, params: D.scrollIntoViewIfNeeded.Params) !D.scrollIntoViewIfNeeded.Result {
    const node = try nodeNamed(session, params.backendNodeId, params.objectId);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const rects = try clientRectsOf(node, arena_state.allocator());
    if (rects.len == 0) return session.fail("Node does not have a layout object");
    // TODO(renderer): platform.setScrollPosition for the node's scrolling
    // ancestors (Blink's ScrollRectToVisible) once a renderer lays out.
    return .{};
}
