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
//! BuildObjectForNode; reproduced, not copied).
//!
//! The nodeId tree (lane tpw, 2026-11-22): DOM.getDocument binds the
//! session's node ids (dom_node_map.zig) to the document and its children to
//! the asked depth; querySelector/querySelectorAll push the path to each
//! result (DOM.setChildNodes for each ancestor whose children the client
//! lacks: PushNodePathToFrontend), requestChildNodes pushes a node's
//! children, getOuterHTML serializes a node, and every node-taking command
//! takes a nodeId. A new top-level document, or its DOMContentLoaded,
//! discards the bindings (DOM.documentUpdated while enabled), as Blink's
//! SetDocument and DomContentLoadedEventFired do. Mutation events
//! (childNodeInserted ...) and editing are CDP part 2 (0.2).

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
const NodeMap = @import("../dom_node_map.zig").NodeMap;
const D = protocol.DOM;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
    /// DOM.enable's includeWhitespace "all": whitespace-only text nodes are
    /// pushed too (Blink's IncludeWhitespace, NONE by default).
    include_whitespace: bool = false,
    /// The client's node ids, made on first push. OWNED.
    map: ?*NodeMap = null,
};

/// The session ends: its node ids go.
pub fn sessionEnded(session: *PageSession) void {
    const s = &session.states.DOM;
    if (s.map) |map| {
        map.deinit();
        session.allocator.destroy(map);
    }
    s.map = null;
}

pub fn enable(session: *PageSession, params: D.enable.Params) !D.enable.Result {
    const s = &session.states.DOM;
    // InspectorDOMAgent::enable: the whitespace choice is made when the
    // agent is first enabled.
    if (!s.enabled) s.include_whitespace = if (params.includeWhitespace) |w| w == .all else false;
    s.enabled = true;
    return .{};
}

pub fn disable(session: *PageSession, params: D.disable.Params) !D.disable.Result {
    _ = params;
    session.states.DOM.enabled = false;
    // SetDocument(nullptr): the client forgets every node.
    if (session.states.DOM.map) |map| map.clear();
    return .{};
}

/// A new document in the session's tab's top frame, or its DOMContentLoaded:
/// the client's nodes are gone. Blink's InspectorDOMAgent::SetDocument (from
/// DidCommitLoad) discards the bindings and sends DOM.documentUpdated at once
/// only for a document that is not parsing - an initial about:blank, or one
/// the back/forward cache shows again (DidRestoreFromBackForwardCache) - and
/// DomContentLoadedEventFired discards them again and sends it for the
/// loaded document. A child frame's new document (Blink's
/// InvalidateFrameOwnerElement: childNodeRemoved/Inserted) is a mutation
/// event: CDP part 2.
pub fn onNavigation(session: *PageSession, milestone: *const frames.Milestone) void {
    if (milestone.navigable_id != session.tab) return;
    const s = &session.states.DOM;
    switch (milestone.event) {
        .committed => |committed| {
            if (s.map) |map| map.clear();
            if (s.enabled and (committed.kind == .initialization or committed.restored)) session.emit(D.documentUpdated, .{});
        },
        .dom_content_loaded => {
            if (s.map) |map| map.clear();
            if (s.enabled) session.emit(D.documentUpdated, .{});
        },
        else => {},
    }
}

/// The session's node ids, made on first use.
fn mapOf(session: *PageSession) !*NodeMap {
    const s = &session.states.DOM;
    if (s.map) |map| return map;
    const map = try session.allocator.create(NodeMap);
    map.* = .init(session.allocator);
    s.map = map;
    return map;
}

/// The inspected frame's document: the session tab's top-level document.
fn topDocument(session: *PageSession) ?*runtime.Instance {
    const top = frames.navigable(session, session.tab) orelse return null;
    return frames.documentOf(top);
}

/// The Browser's node ids.
fn nodeIds(session: *PageSession) ?*NodeIds {
    const browser = session.browser orelse return null;
    return browser.scope.of(NodeIds) catch null;
}

/// Whether the engine has the inspector's remote objects (lane cdpw).
const have_remote_objects = contexts.have_inspector and @hasDecl(engine, "inspectorUnwrap") and @hasDecl(engine, "inspectorWrap");

/// The node a command names (InspectorDOMAgent::AssertNode): by nodeId (the
/// session's bound ids: "Could not find node with given id"), by
/// backendNodeId, or by a remote object's id (unwrapped by the session's
/// inspector session). error.Protocol with Chrome's message otherwise.
fn nodeNamed(session: *PageSession, node_id: ?i64, backend_node_id: ?i64, object_id: ?[]const u8) !*runtime.Instance {
    if (node_id) |id| {
        const map = session.states.DOM.map orelse return session.fail("Could not find node with given id");
        return map.nodeOf(id) orelse session.fail("Could not find node with given id");
    }
    if (backend_node_id) |id| {
        const ids = nodeIds(session) orelse return session.fail("No node with given id found");
        return ids.nodeOf(id) orelse session.fail("No node with given id found");
    }
    if (object_id) |id| {
        if (comptime have_remote_objects) return nodeOfObject(session, id);
        return session.fail("Could not find node with given id");
    }
    return session.fail("Either nodeId, backendNodeId or objectId must be specified");
}

/// The node a remote object id names, unwrapped by the session's inspector
/// session (lane cdpw's bridge: analysed only when the engine has it).
fn nodeOfObject(session: *PageSession, id: []const u8) !*runtime.Instance {
    const inspector = session.states.Runtime.inspector orelse return session.fail("Could not find node with given id");
    const unwrapped = (engine.inspectorUnwrap(inspector, id) catch null) orelse return session.fail("Could not find node with given id");
    defer unwrapped.value.release();
    const instance = engine.convertToPlatformObject(unwrapped.realm, unwrapped.value.borrow()) orelse return session.fail("Object id doesn't reference a Node");
    if (!instance.implements(interfaces.Node.State)) return session.fail("Object id doesn't reference a Node");
    return instance;
}

/// Describe a node (InspectorDOMAgent::describeNode): its kind, names and
/// value, child count and attributes, to `depth` levels of children; its
/// nodeId if the client has it, else 0 (Blink: BuildObjectForNode with no
/// node map binds nothing). With no depth, no children - only
/// childNodeCount: Blink passes depth.value_or(0) (Chrome 157 returned none
/// in 1229 describeNode results, lane cdpr's trace), although the protocol
/// text says the default is 1.
pub fn describeNode(session: *PageSession, params: D.describeNode.Params, reply: Reply(D.describeNode)) !void {
    const node = try nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const depth = params.depth orelse 0;
    const described = try buildNode(session, arena_state.allocator(), node, depth, params.pierce orelse false, null);
    reply.ok(.{ .node = described });
}

/// The document with its children to `depth` (2; -1 for all), binding the
/// session's node ids anew (InspectorDOMAgent::getDocument: an agent not
/// enabled is enabled, the old bindings are discarded, BuildObjectForNode
/// with the agent's node map).
pub fn getDocument(session: *PageSession, params: D.getDocument.Params, reply: Reply(D.getDocument)) !void {
    // "Backward compatibility. Mark agent as enabled when it requests document."
    if (!session.states.DOM.enabled) _ = try enable(session, .{});
    const document = topDocument(session) orelse return session.fail("Document is not available");
    const map = try mapOf(session);
    map.clear();
    var depth = params.depth orelse 2;
    if (depth == -1) depth = std.math.maxInt(i64);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const root = try buildNode(session, arena_state.allocator(), document, depth, params.pierce orelse false, map);
    reply.ok(.{ .root = root });
}

/// Push `node_id`'s children to the client, to `depth` (1; -1 for all)
/// (InspectorDOMAgent::requestChildNodes -> PushChildNodesToFrontend).
pub fn requestChildNodes(session: *PageSession, params: D.requestChildNodes.Params) !D.requestChildNodes.Result {
    var depth = params.depth orelse 1;
    if (depth == 0 or depth < -1) return session.fail("Please provide a positive integer as a depth or -1 for entire subtree");
    if (depth == -1) depth = std.math.maxInt(i64);
    try pushChildNodes(session, params.nodeId, depth, params.pierce orelse false);
    return .{};
}

/// The first element `selector` matches under the bound node `nodeId`, its
/// path pushed to the client (InspectorDOMAgent::querySelector); 0 for none.
pub fn querySelector(session: *PageSession, params: D.querySelector.Params) !D.querySelector.Result {
    const node = try containerNamed(session, params.nodeId);
    var selectors = try runtime.DOMString.initDupe(session.allocator, params.selector);
    defer selectors.deinit(session.allocator);
    const found = interfaces.ParentNode.call_querySelector(node, selectors) catch return session.fail("DOM Error while querying");
    const element = found orelse return .{ .nodeId = 0 };
    return .{ .nodeId = try pushNodePath(session, element) };
}

/// Every element `selector` matches under the bound node `nodeId`, each path
/// pushed to the client (InspectorDOMAgent::querySelectorAll).
pub fn querySelectorAll(session: *PageSession, params: D.querySelectorAll.Params, reply: Reply(D.querySelectorAll)) !void {
    const node = try containerNamed(session, params.nodeId);
    var selectors = try runtime.DOMString.initDupe(session.allocator, params.selector);
    defer selectors.deinit(session.allocator);
    const list = interfaces.ParentNode.call_querySelectorAll(node, selectors) catch return session.fail("DOM Error while querying");
    const generation = runtime.SlabAllocator.generationOf(list);
    defer list.releaseIfUnwrapped(generation);
    const length = interfaces.NodeList.get_length(list) catch 0;
    const node_ids = try session.allocator.alloc(i64, length);
    defer session.allocator.free(node_ids);
    var i: u32 = 0;
    while (i < length) : (i += 1) {
        const element = (interfaces.NodeList.call_item(list, i) catch null) orelse {
            node_ids[i] = 0;
            continue;
        };
        node_ids[i] = try pushNodePath(session, element);
    }
    reply.ok(.{ .nodeIds = node_ids });
}

/// The node's markup, the node itself included (InspectorDOMAgent::
/// getOuterHTML: CreateMarkup with kIncludeNode); with includeShadowDOM,
/// every shadow root in it as a declarative one (Blink's
/// kIncludeAllShadowRootsForInspector).
pub fn getOuterHTML(session: *PageSession, params: D.getOuterHTML.Params, reply: Reply(D.getOuterHTML)) !void {
    const node = try nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
    const serialization = @import("html").serialization;
    var markup = if (params.includeShadowDOM orelse false) blk: {
        var roots: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
        defer roots.deinit(session.allocator);
        try collectShadowRoots(session.allocator, node, &roots);
        break :blk serialization.outerWithShadowRoots(node, roots.items) catch return session.fail("Could not serialize node");
    } else serialization.outer(node) catch return session.fail("Could not serialize node");
    defer markup.deinit(node.ctx.allocator);
    reply.ok(.{ .outerHTML = markup.asSlice() });
}

/// Every shadow root in `node`'s subtree, closed ones too, in tree order.
fn collectShadowRoots(allocator: Allocator, node: *runtime.Instance, roots: *std.ArrayListUnmanaged(*runtime.Instance)) !void {
    if (node.implements(interfaces.Element.State)) {
        if (@import("dom").shadow_hosts.rootForHost(node)) |root| {
            try roots.append(allocator, root);
            try collectShadowRoots(allocator, root, roots);
        }
    }
    var child = interfaces.Node.get_firstChild(try @import("dom").template_contents.insertionTarget(node)) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) try collectShadowRoots(allocator, c, roots);
}

/// The bound node `node_id`, which must be a container (an element, a
/// document or a fragment): Blink's AssertNode, then "Not a container node".
fn containerNamed(session: *PageSession, node_id: i64) !*runtime.Instance {
    const node = try nodeNamed(session, node_id, null, null);
    const node_type = interfaces.Node.get_nodeType(node) catch 0;
    if (node_type != 1 and node_type != 9 and node_type != 11) return session.fail("Not a container node");
    return node;
}

// ============================================================================
// Pushing nodes to the client (InspectorDOMAgent)
// ============================================================================

/// ShouldSkipNode: a whitespace-only text node is not pushed unless
/// DOM.enable asked for whitespace.
fn skipped(session: *const PageSession, node: ?*runtime.Instance) bool {
    const n = node orelse return false;
    if (session.states.DOM.include_whitespace) return false;
    if ((interfaces.Node.get_nodeType(n) catch 0) != 3) return false;
    var value = (interfaces.Node.get_nodeValue(n) catch null) orelse return true;
    defer value.deinit(n.ctx.allocator);
    for (value.asSlice()) |c| if (!std.ascii.isWhitespace(c)) return false;
    return true;
}

/// InnerFirstChild / InnerNextSibling: the children the client sees.
fn innerFirstChild(session: *const PageSession, node: *runtime.Instance) ?*runtime.Instance {
    var child = interfaces.Node.get_firstChild(node) catch null;
    while (skipped(session, child)) child = interfaces.Node.get_nextSibling(child.?) catch null;
    return child;
}

fn innerNextSibling(session: *const PageSession, node: *runtime.Instance) ?*runtime.Instance {
    var next = interfaces.Node.get_nextSibling(node) catch null;
    while (skipped(session, next)) next = interfaces.Node.get_nextSibling(next.?) catch null;
    return next;
}

/// InnerParentNode: a document's frame owner element, a shadow root's host,
/// else the parent node.
fn innerParent(session: *PageSession, node: *runtime.Instance) ?*runtime.Instance {
    const node_type = interfaces.Node.get_nodeType(node) catch 0;
    if (node_type == 9) {
        const bc = frameOfDocument(session, node) orelse return null;
        const container = bc.container orelse return null;
        const owner: *runtime.Instance = @ptrCast(@alignCast(container));
        return owner;
    }
    if (node.implements(interfaces.ShadowRoot.State)) return interfaces.ShadowRoot.get_host(node) catch null;
    return interfaces.Node.get_parentNode(node) catch null;
}

/// PushChildNodesToFrontend: the bound node `node_id`'s children, to
/// `depth`, sent as DOM.setChildNodes - or, for children the client has,
/// their children further down.
fn pushChildNodes(session: *PageSession, node_id: i64, depth: i64, pierce: bool) !void {
    const map = session.states.DOM.map orelse return;
    const node = map.nodeOf(node_id) orelse return;
    const node_type = interfaces.Node.get_nodeType(node) catch 0;
    if (node_type != 1 and node_type != 9 and node_type != 11) return;
    if (map.childrenRequested(node_id)) {
        if (depth <= 1) return;
        var child = innerFirstChild(session, node);
        while (child) |c| : (child = innerNextSibling(session, c)) {
            const child_id = map.boundId(c);
            if (child_id != 0) try pushChildNodes(session, child_id, depth - 1, pierce);
        }
        return;
    }
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const children = try buildChildren(session, arena_state.allocator(), node, depth, pierce, map);
    session.emit(D.setChildNodes, .{ .parentId = node_id, .nodes = children });
}

/// PushNodePathToFrontend: `node`'s id, after the client has been sent every
/// ancestor's children down from the nearest bound ancestor; 0 when the
/// client has no document, or the node is outside it (Blink's detached-
/// subtree push is not part of this command set).
fn pushNodePath(session: *PageSession, node: *runtime.Instance) !i64 {
    const map = session.states.DOM.map orelse return 0;
    const document = topDocument(session) orelse return 0;
    if (map.boundId(document) == 0) return 0;
    const known = map.boundId(node);
    if (known != 0) return known;
    var path: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer path.deinit(session.allocator);
    var current = node;
    while (true) {
        const parent = innerParent(session, current) orelse return 0;
        try path.append(session.allocator, parent);
        if (map.boundId(parent) != 0) break;
        current = parent;
    }
    var i = path.items.len;
    while (i > 0) {
        i -= 1;
        const id = map.boundId(path.items[i]);
        if (id != 0) try pushChildNodes(session, id, 1, false);
    }
    return map.boundId(node);
}

/// Blink's BuildObjectForNode. With `map` the node and what is built under it
/// are bound (pushed to the client); without one a node's id is the one the
/// client has, if any.
fn buildNode(session: *PageSession, arena: Allocator, node: *runtime.Instance, depth_in: i64, pierce: bool, map: ?*NodeMap) Allocator.Error!D.Node {
    var depth = depth_in;
    const ids = nodeIds(session) orelse return error.OutOfMemory;
    const node_id: i64 = if (map) |m| try m.bind(node) else if (session.states.DOM.map) |m| m.boundId(node) else 0;
    const node_type = interfaces.Node.get_nodeType(node) catch 0;
    var name = interfaces.Node.get_nodeName(node) catch runtime.DOMString.initEmpty();
    defer name.deinit(node.ctx.allocator);
    var described: D.Node = .{
        .nodeId = node_id,
        .backendNodeId = try ids.idOf(node),
        .nodeType = node_type,
        .nodeName = try arena.dupe(u8, name.asSlice()),
        .localName = "",
        .nodeValue = "",
    };
    var force_push_children = false;
    switch (node_type) {
        // ELEMENT_NODE
        1 => {
            var local = interfaces.Element.get_localName(node) catch runtime.DOMString.initEmpty();
            defer local.deinit(node.ctx.allocator);
            described.localName = try arena.dupe(u8, local.asSlice());
            described.attributes = try attributesOf(arena, node);
            if (isSvg(node)) described.isSVG = true;
            // A frame owner: its content frame, and its document (to the
            // depth only when piercing).
            if (contentNavigableOf(session, node)) |bc| {
                described.frameId = try arena.dupe(u8, session.frameId(bc.id).slice());
                if (frames.documentOf(bc)) |document| {
                    const content = try arena.create(D.Node);
                    content.* = try buildNode(session, arena, document, if (pierce) depth else 0, pierce, map);
                    described.contentDocument = content;
                }
            }
            // The document element names its document's frame.
            if (interfaces.Node.get_parentNode(node) catch null) |parent| {
                if ((interfaces.Node.get_nodeType(parent) catch 0) == 9) {
                    if (frameOfDocument(session, parent)) |bc| described.frameId = try arena.dupe(u8, session.frameId(bc.id).slice());
                }
            }
            // A shadow host's root (closed too), to the depth only when
            // piercing; the host's children go with it.
            if (@import("dom").shadow_hosts.rootForHost(node)) |root| {
                const roots = try arena.alloc(D.Node, 1);
                roots[0] = try buildNode(session, arena, root, if (pierce) depth else 0, pierce, map);
                described.shadowRoots = roots;
                force_push_children = true;
            }
            // A link element's children go with it (Blink: imports once).
            if (isHtmlElementNamed(node, "link")) force_push_children = true;
            // A template's contents.
            if (isHtmlElementNamed(node, "template")) {
                if (interfaces.HTMLTemplateElement.get_content(node) catch null) |content| {
                    const template_content = try arena.create(D.Node);
                    template_content.* = try buildNode(session, arena, content, 0, pierce, map);
                    described.templateContent = template_content;
                    force_push_children = true;
                }
            }
        },
        // TEXT, CDATA_SECTION, PROCESSING_INSTRUCTION, COMMENT: the value,
        // at most 10,000 characters and an ellipsis (Blink kMaxTextSize).
        3, 4, 7, 8 => {
            if (interfaces.Node.get_nodeValue(node) catch null) |value| {
                var v = value;
                defer v.deinit(node.ctx.allocator);
                described.nodeValue = try truncatedText(arena, v.asSlice());
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
            described.compatibilityMode = compatibilityModeOf(node);
            if (frameOfDocument(session, node)) |bc| described.frameId = try arena.dupe(u8, session.frameId(bc.id).slice());
        },
        // DOCUMENT_TYPE_NODE
        10 => {
            var public_id = interfaces.DocumentType.get_publicId(node) catch runtime.DOMString.initEmpty();
            defer public_id.deinit(node.ctx.allocator);
            var system_id = interfaces.DocumentType.get_systemId(node) catch runtime.DOMString.initEmpty();
            defer system_id.deinit(node.ctx.allocator);
            described.publicId = try arena.dupe(u8, public_id.asSlice());
            described.systemId = try arena.dupe(u8, system_id.asSlice());
        },
        // DOCUMENT_FRAGMENT_NODE: a shadow root's type.
        11 => {
            if (node.implements(interfaces.ShadowRoot.State)) {
                described.shadowRootType = switch (interfaces.ShadowRoot.get_mode(node) catch ._open_) {
                    ._open_ => .open,
                    ._closed_ => .closed,
                };
            }
        },
        else => {},
    }
    // Containers: how many children the client sees, and the children to
    // `depth` (a bound node whose children are forced: one level).
    if (node_type == 1 or node_type == 9 or node_type == 11) {
        var count: i64 = 0;
        var child = innerFirstChild(session, node);
        while (child) |c| : (child = innerNextSibling(session, c)) count += 1;
        described.childNodeCount = count;
        if (map != null and force_push_children and depth == 0) depth = 1;
        const children = try buildChildren(session, arena, node, depth, pierce, map);
        if (children.len != 0 or depth != 0) described.children = children;
    }
    return described;
}

/// BuildArrayForContainerChildren: `container`'s children to `depth`, each
/// with its parentId. At depth 0 with a node map, an only text child is
/// pushed anyway, as if the container's children had been asked for.
fn buildChildren(session: *PageSession, arena: Allocator, container: *runtime.Instance, depth: i64, pierce: bool, map: ?*NodeMap) Allocator.Error![]const D.Node {
    var children: std.ArrayListUnmanaged(D.Node) = .empty;
    if (depth == 0) {
        const m = map orelse return children.items;
        const first = interfaces.Node.get_firstChild(container) catch null;
        if (first) |only| {
            if ((interfaces.Node.get_nodeType(only) catch 0) == 3 and (interfaces.Node.get_nextSibling(only) catch null) == null) {
                var child_node = try buildNode(session, arena, only, 0, pierce, map);
                const parent_id = try m.bind(container);
                child_node.parentId = parent_id;
                try children.append(arena, child_node);
                try m.markChildrenRequested(parent_id);
            }
        }
        return children.items;
    }
    const parent_id: i64 = if (map) |m| try m.bind(container) else 0;
    if (map) |m| try m.markChildrenRequested(parent_id);
    var child = innerFirstChild(session, container);
    while (child) |c| : (child = innerNextSibling(session, c)) {
        var child_node = try buildNode(session, arena, c, depth - 1, pierce, map);
        if (map != null) child_node.parentId = parent_id;
        try children.append(arena, child_node);
    }
    return children.items;
}

/// Blink kMaxTextSize: a longer value is cut, with an ellipsis (U+2026).
fn truncatedText(arena: Allocator, value: []const u8) Allocator.Error![]const u8 {
    const max_text_size = 10_000;
    // The limit counts UTF-16 code units in Blink; count code points here,
    // the same for every character in the BMP.
    const view = std.unicode.Utf8View.init(value) catch return arena.dupe(u8, value);
    var it = view.iterator();
    var count: usize = 0;
    while (it.nextCodepointSlice()) |_| {
        count += 1;
        if (count == max_text_size) {
            return std.mem.concat(arena, u8, &.{ value[0..it.i], "\u{2026}" });
        }
    }
    return arena.dupe(u8, value);
}

/// The document's mode as CDP's compatibilityMode.
fn compatibilityModeOf(document: *runtime.Instance) ?D.CompatibilityMode {
    const mode = @import("dom").document_internals.getMode(document) orelse return null;
    return switch (mode) {
        .quirks => .QuirksMode,
        .limited_quirks => .LimitedQuirksMode,
        .no_quirks => .NoQuirksMode,
    };
}

/// An element in the SVG namespace (Blink's IsSVGElement).
fn isSvg(element: *runtime.Instance) bool {
    var ns = (interfaces.Element.get_namespaceURI(element) catch null) orelse return false;
    defer ns.deinit(element.ctx.allocator);
    return std.mem.eql(u8, ns.asSlice(), "http://www.w3.org/2000/svg");
}

/// An HTML element with local name `name`.
fn isHtmlElementNamed(element: *runtime.Instance, comptime name: []const u8) bool {
    var ns = (interfaces.Element.get_namespaceURI(element) catch null) orelse return false;
    defer ns.deinit(element.ctx.allocator);
    if (!std.mem.eql(u8, ns.asSlice(), "http://www.w3.org/1999/xhtml")) return false;
    var local = interfaces.Element.get_localName(element) catch return false;
    defer local.deinit(element.ctx.allocator);
    return std.mem.eql(u8, local.asSlice(), name);
}

/// An element's attributes, flattened [name, value, ...] in order.
fn attributesOf(arena: Allocator, element: *runtime.Instance) Allocator.Error!?[]const []const u8 {
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
    // InspectorDOMAgent::resolveNode: exactly one of the two ids.
    if ((params.nodeId != null) == (params.backendNodeId != null)) return session.fail("Either nodeId or backendNodeId must be specified.");
    const node = if (params.nodeId) |id| blk: {
        const map = session.states.DOM.map orelse return session.fail("No node with given id found");
        break :blk map.nodeOf(id) orelse return session.fail("No node with given id found");
    } else try nodeNamed(session, null, params.backendNodeId, null);
    if (comptime have_remote_objects) return resolveNodeLive(session, params, reply, node);
    return session.fail("Node with given id does not belong to the document");
}

/// `resolveNode` with the inspector's remote objects (lane cdpw's bridge).
fn resolveNodeLive(session: *PageSession, params: D.resolveNode.Params, reply: Reply(D.resolveNode), node: *runtime.Instance) !void {
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
    const node = try nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
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
    const node = try nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
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
    const node = try nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const rects = try clientRectsOf(node, arena_state.allocator());
    if (rects.len == 0) return session.fail("Node does not have a layout object");
    // TODO(renderer): platform.setScrollPosition for the node's scrolling
    // ancestors (Blink's ScrollRectToVisible) once a renderer lays out.
    return .{};
}
