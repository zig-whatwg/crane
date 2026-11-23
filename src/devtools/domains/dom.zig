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
//! SetDocument and DomContentLoadedEventFired do.
//!
//! The live DOM (lane cdpd1, roadmap cdp-live-dom; design
//! tmp/plans/cdpd1-design.md): an enabled agent hears the DOM's probes
//! (dom.inspector_probes, through dom_events.zig) and sends what Blink's
//! InspectorDOMAgent sends for each (inspector_dom_agent.cc at Chrome
//! 157.0.8103.78: DidInsertDOMNode, WillRemoveDOMNode / DOMNodeRemoved,
//! DidModifyDOMAttr, DidRemoveDOMAttr, CharacterDataModified,
//! DidInvalidateStyleAttr with its InspectorRevalidateDOMTask,
//! DidPushShadowRoot, TopLayerElementsChanged, and DidCommitLoad's
//! InvalidateFrameOwnerElement for a child frame). shadowRootPopped is never
//! sent: Blink declares WillPopShadowRoot (core_probes.pidl) and its agent
//! handles it, but nothing calls the probe (no call site in Chromium 145 or
//! 157: a shadow root is never detached since Shadow DOM v0 went), so Chrome
//! never sends the event either.

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
const dom_events = @import("../dom_events.zig");
const dom = @import("dom");
const D = protocol.DOM;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
    /// DOM.enable's includeWhitespace "all": whitespace-only text nodes are
    /// pushed too (Blink's IncludeWhitespace, NONE by default).
    include_whitespace: bool = false,
    /// The client's node ids, made on first push. OWNED.
    map: ?*NodeMap = null,
    /// InspectorRevalidateDOMTask's style_attr_invalidated_elements_: the
    /// bound elements whose inline style was invalidated since the last
    /// DOM.inlineStyleInvalidated, in order, as names (never a hold).
    pending_style: std.ArrayListUnmanaged(WeakNode) = .empty,
    /// The task that sends them, while one is queued (its timer).
    revalidate: ?*RevalidateTask = null,
};

/// A node named without a hold: its address and slab generation.
const WeakNode = struct {
    node: *runtime.Instance,
    generation: u64,

    fn of(node: *runtime.Instance) WeakNode {
        return .{ .node = node, .generation = runtime.SlabAllocator.generationOf(node) };
    }

    fn get(self: WeakNode) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.node) != self.generation) return null;
        return self.node;
    }
};

/// The session ends: its agent stops hearing the probes, and its node ids go.
pub fn sessionEnded(session: *PageSession) void {
    const s = &session.states.DOM;
    if (s.enabled) {
        if (session.side) |side| dom_events.unregister(side, session);
        s.enabled = false;
    }
    resetRevalidation(session);
    s.pending_style.deinit(session.allocator);
    s.pending_style = .empty;
    if (s.map) |map| {
        map.deinit();
        session.allocator.destroy(map);
    }
    s.map = null;
}

/// InspectorDOMAgent::enable -> EnableAndReset: the agent hears the DOM's
/// probes from now on; the whitespace choice is made when it is first
/// enabled.
pub fn enable(session: *PageSession, params: D.enable.Params) !D.enable.Result {
    const s = &session.states.DOM;
    if (s.enabled) return .{};
    if (session.side) |side| try dom_events.register(side, session);
    s.include_whitespace = if (params.includeWhitespace) |w| w == .all else false;
    s.enabled = true;
    return .{};
}

/// InspectorDOMAgent::disable: "DOM agent hasn't been enabled" when it is
/// not; else it stops hearing the probes and SetDocument(nullptr) discards
/// every binding.
pub fn disable(session: *PageSession, params: D.disable.Params) !D.disable.Result {
    _ = params;
    const s = &session.states.DOM;
    if (!s.enabled) return session.fail("DOM agent hasn't been enabled");
    if (session.side) |side| dom_events.unregister(side, session);
    s.enabled = false;
    s.include_whitespace = false;
    discardBindings(session);
    return .{};
}

/// DiscardFrontendBindings: the client forgets every node, and the pending
/// style revalidation is stopped (revalidate_task_->Reset()).
fn discardBindings(session: *PageSession) void {
    const s = &session.states.DOM;
    if (s.map) |map| map.clear();
    resetRevalidation(session);
}

/// A new document in the session's tab's top frame, or its DOMContentLoaded:
/// the client's nodes are gone. Blink's InspectorDOMAgent::SetDocument (from
/// DidCommitLoad) discards the bindings and sends DOM.documentUpdated at once
/// only for a document that is not parsing - an initial about:blank, or one
/// the back/forward cache shows again (DidRestoreFromBackForwardCache) - and
/// DomContentLoadedEventFired discards them again and sends it for the
/// loaded document. A child frame's new document re-sends its owner
/// (DidCommitLoad -> InvalidateFrameOwnerElement: childNodeRemoved, then
/// childNodeInserted).
pub fn onNavigation(session: *PageSession, milestone: *const frames.Milestone) void {
    const s = &session.states.DOM;
    if (milestone.navigable_id != session.tab) {
        // DidCommitLoad for a frame other than the inspected root:
        // InvalidateFrameOwnerElement(its owner).
        switch (milestone.event) {
            .committed => if (s.enabled) invalidateFrameOwnerElement(session, milestone.navigable_id),
            else => {},
        }
        return;
    }
    switch (milestone.event) {
        .committed => |committed| {
            discardBindings(session);
            if (s.enabled and (committed.kind == .initialization or committed.restored)) session.emit(D.documentUpdated, .{});
        },
        .dom_content_loaded => {
            discardBindings(session);
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
// The live DOM: the probes' handlers (dom_events.zig calls them for each
// enabled agent; InspectorDOMAgent's probe methods)
// ============================================================================

/// DidInsertDOMNode: `node` was just linked into its parent. A whitespace-
/// only text node is not the client's (ShouldSkipNode); its old bindings go
/// ("We could be attaching existing subtree. Forget the bindings."); then,
/// under a bound parent, childNodeInserted - or, when the client has not
/// been sent the parent's children, childNodeCountUpdated from the count it
/// has ("No children are mapped yet -> only notify on changes of child
/// count").
pub fn didInsertDOMNode(session: *PageSession, node: *runtime.Instance) void {
    if (skipped(session, node)) return;
    const map = session.states.DOM.map orelse return;
    unbind(session, map, node);
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return;
    const parent_id = map.boundId(parent);
    if (parent_id == 0) return;
    if (!map.childrenRequested(parent_id)) {
        const count = map.childCount(parent_id) + 1;
        map.setChildCount(parent_id, count) catch return;
        session.emit(D.childNodeCountUpdated, .{ .nodeId = parent_id, .childNodeCount = count });
        return;
    }
    const previous = innerPreviousSibling(session, node);
    const previous_id = if (previous) |p| map.boundId(p) else 0;
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const value = buildNode(session, arena_state.allocator(), node, 0, false, map) catch return;
    session.emit(D.childNodeInserted, .{ .parentNodeId = parent_id, .previousNodeId = previous_id, .node = value });
}

/// WillRemoveDOMNode: `node` is about to leave its parent.
pub fn willRemoveDOMNode(session: *PageSession, node: *runtime.Instance) void {
    if (skipped(session, node)) return;
    domNodeRemoved(session, node);
}

/// DOMNodeRemoved: under a bound parent, childNodeRemoved - or
/// childNodeCountUpdated when the client has not been sent the parent's
/// children - and the node's bindings go.
fn domNodeRemoved(session: *PageSession, node: *runtime.Instance) void {
    const map = session.states.DOM.map orelse return;
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return;
    // "If parent is not mapped yet -> ignore the event."
    const parent_id = map.boundId(parent);
    if (parent_id == 0) return;
    if (!map.childrenRequested(parent_id)) {
        const count = map.childCount(parent_id) - 1;
        map.setChildCount(parent_id, count) catch return;
        session.emit(D.childNodeCountUpdated, .{ .nodeId = parent_id, .childNodeCount = count });
    } else {
        session.emit(D.childNodeRemoved, .{ .parentNodeId = parent_id, .nodeId = map.boundId(node) });
    }
    unbind(session, map, node);
}

/// DidModifyDOMAttr / DidRemoveDOMAttr: a bound element's attribute was set
/// to `value` (null: removed). The probe left out a set to the same value.
pub fn didModifyDOMAttr(session: *PageSession, element: *runtime.Instance, name: dom.inspector_probes.AttributeName, value: ?[]const u8) void {
    const map = session.states.DOM.map orelse return;
    // "If node is not mapped yet -> ignore the event."
    const id = map.boundId(element);
    if (id == 0) return;
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const qualified = qualifiedName(arena_state.allocator(), name.prefix, name.local_name) catch return;
    if (value) |v| {
        session.emit(D.attributeModified, .{ .nodeId = id, .name = qualified, .value = v });
    } else {
        session.emit(D.attributeRemoved, .{ .nodeId = id, .name = qualified });
    }
}

/// CharacterDataModified: a bound node turned whitespace-only leaves the
/// client (DOMNodeRemoved); an unbound one is pushed as an insertion ("Push
/// text node if it is being created"); else characterDataModified with the
/// whole data (Blink sends data(), uncut).
pub fn characterDataModified(session: *PageSession, node: *runtime.Instance) void {
    const map = session.states.DOM.map orelse return;
    const id = map.boundId(node);
    if (id != 0 and skipped(session, node)) {
        domNodeRemoved(session, node);
        return;
    }
    if (id == 0) {
        didInsertDOMNode(session, node);
        return;
    }
    const data = dom.character_data.dataOf(node) orelse return;
    session.emit(D.characterDataModified, .{ .nodeId = id, .characterData = data });
}

/// DidInvalidateStyleAttr: a bound element's inline style changed; it joins
/// the pending set, and the revalidation task is queued if it is not
/// (InspectorRevalidateDOMTask::ScheduleStyleAttrRevalidationFor: a one-shot
/// zero-delay timer on the document's DOM manipulation task runner).
pub fn didInvalidateStyleAttr(session: *PageSession, element: *runtime.Instance) void {
    const s = &session.states.DOM;
    const map = s.map orelse return;
    if (map.boundId(element) == 0) return;
    const pending_already = for (s.pending_style.items) |pending| {
        if (pending.get() == element) break true;
    } else false;
    if (!pending_already) s.pending_style.append(session.allocator, WeakNode.of(element)) catch return;
    if (s.revalidate != null) return;
    const loop = element.ctx.getOptionalEventLoop() orelse return;
    const task = session.allocator.create(RevalidateTask) catch return;
    task.* = .{ .session = session, .allocator = session.allocator };
    s.revalidate = task;
    loop.queueTask(.{ .callback = RevalidateTask.run, .context = task, .drop = RevalidateTask.drop });
}

/// The queued revalidation (InspectorRevalidateDOMTask's timer). It names
/// its session until the session's agent resets it (a discard, a disable,
/// the session's end), and frees itself when it runs or is dropped.
pub const RevalidateTask = struct {
    session: ?*PageSession,
    allocator: Allocator,

    fn run(context: ?*anyopaque) void {
        const self: *RevalidateTask = @ptrCast(@alignCast(context.?));
        defer self.allocator.destroy(self);
        const session = self.session orelse return;
        session.states.DOM.revalidate = null;
        styleAttributeInvalidated(session);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *RevalidateTask = @ptrCast(@alignCast(context.?));
        if (self.session) |session| session.states.DOM.revalidate = null;
        self.allocator.destroy(self);
    }
};

/// InspectorRevalidateDOMTask::Reset: the queued task sends nothing. Blink
/// stops the timer and keeps the set; the set's stale names are dropped
/// here, which sends the same (StyleAttributeInvalidated skips the unbound).
fn resetRevalidation(session: *PageSession) void {
    const s = &session.states.DOM;
    if (s.revalidate) |task| task.session = null;
    s.revalidate = null;
    s.pending_style.clearRetainingCapacity();
}

/// StyleAttributeInvalidated: one inlineStyleInvalidated with the pending
/// elements the client still has. Blink iterates a HeapHashSet, so its ids
/// come in pointer-hash order; these come in the order they were invalidated.
fn styleAttributeInvalidated(session: *PageSession) void {
    const s = &session.states.DOM;
    defer s.pending_style.clearRetainingCapacity();
    const map = s.map orelse return;
    if (s.pending_style.items.len == 0) return;
    const ids = session.allocator.alloc(i64, s.pending_style.items.len) catch return;
    defer session.allocator.free(ids);
    var n: usize = 0;
    for (s.pending_style.items) |pending| {
        const element = pending.get() orelse continue;
        const id = map.boundId(element);
        if (id == 0) continue;
        ids[n] = id;
        n += 1;
    }
    session.emit(D.inlineStyleInvalidated, .{ .nodeIds = ids[0..n] });
}

/// DidPushShadowRoot: a bound host's children are pushed (one level), then
/// shadowRootPushed with the root built at depth 0.
pub fn didPushShadowRoot(session: *PageSession, host: *runtime.Instance, root: *runtime.Instance) void {
    const map = session.states.DOM.map orelse return;
    if ((interfaces.Node.get_ownerDocument(host) catch null) == null) return;
    const host_id = map.boundId(host);
    if (host_id == 0) return;
    pushChildNodes(session, host_id, 1, false) catch return;
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const value = buildNode(session, arena_state.allocator(), root, 0, false, map) catch return;
    session.emit(D.shadowRootPushed, .{ .hostId = host_id, .root = value });
}

/// TopLayerElementsChanged: the top layer of a document in the session's
/// tab changed - sent with no binding check, as Blink's agent sends it to
/// every enabled agent of the frame's local root.
pub fn topLayerElementsChanged(session: *PageSession, document: *runtime.Instance) void {
    if (frameOfDocument(session, document) == null) return;
    session.emit(D.topLayerElementsUpdated, .{});
}

/// InvalidateFrameOwnerElement: a child frame committed a new document, so
/// its owner is sent again with it: childNodeRemoved, the owner's bindings
/// dropped, childNodeInserted ("Re-add frame owner element together with its
/// new children").
fn invalidateFrameOwnerElement(session: *PageSession, navigable_id: u64) void {
    if (!frames.inTab(session, navigable_id)) return;
    const bc = frames.navigable(session, navigable_id) orelse return;
    const container = bc.container orelse return;
    const owner: *runtime.Instance = @ptrCast(@alignCast(container));
    const map = session.states.DOM.map orelse return;
    const owner_id = map.boundId(owner);
    if (owner_id == 0) return;
    const parent_id = if (innerParent(session, owner)) |parent| map.boundId(parent) else 0;
    session.emit(D.childNodeRemoved, .{ .parentNodeId = parent_id, .nodeId = owner_id });
    unbind(session, map, owner);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const value = buildNode(session, arena_state.allocator(), owner, 0, false, map) catch return;
    const previous = innerPreviousSibling(session, owner);
    const previous_id = if (previous) |p| map.boundId(p) else 0;
    session.emit(D.childNodeInserted, .{ .parentNodeId = parent_id, .previousNodeId = previous_id, .node = value });
}

/// Unbind: `node`'s binding goes, with its content document's and its
/// shadow root's, and - for a node whose children the client had - each
/// inner child's, down the tree. A work list, not recursion: a client can
/// hold a whole document of any depth.
fn unbind(session: *PageSession, map: *NodeMap, node: *runtime.Instance) void {
    var stack: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer stack.deinit(session.allocator);
    var next: ?*runtime.Instance = node;
    while (next) |current| : (next = stack.pop()) {
        const forgotten = map.forget(current);
        if (forgotten.id == 0) continue;
        if ((interfaces.Node.get_nodeType(current) catch 0) == 1) {
            if (contentNavigableOf(session, current)) |bc| {
                if (frames.documentOf(bc)) |document| stack.append(session.allocator, document) catch {};
            }
            if (dom.shadow_hosts.rootForHost(current)) |root| stack.append(session.allocator, root) catch {};
        }
        if (forgotten.children_requested) {
            var child = innerFirstChild(session, current);
            while (child) |c| : (child = innerNextSibling(session, c)) stack.append(session.allocator, c) catch {};
        }
    }
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
    // The data in place (dom.character_data), no copy: every probe asks.
    const value = dom.character_data.dataOf(n) orelse return true;
    return isBlinkWhitespace(value);
}

/// Blink's String::LengthWithStrippedWhiteSpace() == 0: every character is
/// IsSpaceOrNewline - an ASCII space (U+0009-U+000D, U+0020), or above
/// U+007F a character whose bidi class is WS (U+1680, U+2000-U+200A, U+2028,
/// U+205F, U+3000; wtf/text/ascii_ctype.h, character_names via
/// u_charDirection).
fn isBlinkWhitespace(value: []const u8) bool {
    const view = std.unicode.Wtf8View.init(value) catch return false;
    var it = view.iterator();
    while (it.nextCodepoint()) |c| {
        const space = switch (c) {
            0x09...0x0D, 0x20, 0x1680, 0x2000...0x200A, 0x2028, 0x205F, 0x3000 => true,
            else => false,
        };
        if (!space) return false;
    }
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

/// InnerPreviousSibling.
fn innerPreviousSibling(session: *const PageSession, node: *runtime.Instance) ?*runtime.Instance {
    var previous = interfaces.Node.get_previousSibling(node) catch null;
    while (skipped(session, previous)) previous = interfaces.Node.get_previousSibling(previous.?) catch null;
    return previous;
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
        // The count the client now has: childNodeCountUpdated's base
        // (cached_child_count_, for the document's map).
        if (map) |m| try m.setChildCount(node_id, count);
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

/// An element's attributes, flattened [name, value, ...] in order (Blink's
/// BuildArrayForElementAttributes: QualifiedName::ToString and the value),
/// read from the attribute list itself - not through Element.attributes,
/// whose NamedNodeMap would make an Attr node for each.
fn attributesOf(arena: Allocator, element: *runtime.Instance) Allocator.Error!?[]const []const u8 {
    const count = dom.element_attributes.count(element);
    if (count == 0) return &.{};
    const out = try arena.alloc([]const u8, count * 2);
    var n: usize = 0;
    for (0..count) |i| {
        const attribute = dom.element_attributes.at(element, i) orelse continue;
        out[n] = try qualifiedName(arena, attribute.prefix, attribute.local_name);
        out[n + 1] = try arena.dupe(u8, attribute.value);
        n += 2;
    }
    return out[0..n];
}

/// Blink's QualifiedName::ToString: "prefix:localName", or the local name.
fn qualifiedName(arena: Allocator, prefix: ?[]const u8, local_name: []const u8) Allocator.Error![]const u8 {
    const p = prefix orelse return arena.dupe(u8, local_name);
    if (p.len == 0) return arena.dupe(u8, local_name);
    return std.mem.concat(arena, u8, &.{ p, ":", local_name });
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
