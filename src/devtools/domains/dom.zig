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
const StyleSheetIds = @import("../style_sheet_ids.zig").StyleSheetIds;
const Bindings = @import("../dom_node_map.zig").Bindings;
const dom_events = @import("../dom_events.zig");
const dom_search = @import("../dom_search.zig");
const dom_editor = @import("../dom_editor.zig");
const dom_patch = @import("../dom_patch.zig");
const dom = @import("dom");
const infra = @import("infra");
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
    /// DOM.performSearch's results by search id (Blink's search_results_),
    /// each node HELD until the search is discarded (dom.node_holds.RefHold:
    /// Blink keeps them as Member<Node>). Keys and lists OWNED.
    searches: std.StringArrayHashMapUnmanaged([]RefHold) = .empty,
    /// The last search id's number (IdentifiersFactory::CreateIdentifier).
    last_search: u64 = 0,
    /// DOM.setNodeStackTracesEnabled (capture_node_stack_traces_).
    capture_node_stack_traces: bool = false,
    /// Each node's creation stack, Runtime.StackTrace JSON OWNED, by node
    /// address (node_to_creation_source_location_map_, a weak map: an
    /// entry whose node is gone is swept as the map grows).
    creation_stacks: std.AutoHashMapUnmanaged(usize, CreationStack) = .empty,
    creation_stacks_guard: infra.tombstones.TombstoneGuard = .{},
    /// The size at which the next sweep runs.
    creation_sweep_at: usize = 1024,
    /// The edits' history (InspectorHistory), made when the agent is
    /// enabled (EnableAndReset) and dropped when it is disabled. OWNED.
    history: ?*dom_editor.History = null,
    /// The bound slots whose assigned nodes changed since the last
    /// rendering update, as names (Blink reports a distribution when its
    /// lazy recalculation runs: dom.inspector_probes.slotAssignmentChanged).
    pending_slots: std.ArrayListUnmanaged(WeakNode) = .empty,
    /// InspectorRevalidateDOMTask's adopted_style_sheet_invalidated_elements_:
    /// the documents and shadow roots whose adoptedStyleSheets changed, as
    /// names, sent with the revalidation task.
    pending_adopted: std.ArrayListUnmanaged(WeakNode) = .empty,
    /// The pseudo-elements the client was told of, per bound element, by
    /// address (with the element's generation): what the next rendering
    /// update compares with (PseudoElementCreated / Destroyed).
    pseudo_state: std.AutoHashMapUnmanaged(usize, PseudoRecord) = .empty,
    pseudo_state_guard: infra.tombstones.TombstoneGuard = .{},
    /// The top layer's elements that had a ::backdrop at the last rendering
    /// update, by name: Blink keeps each ::backdrop in the top layer list
    /// beside its element (Document::AddToTopLayer(backdrop, element)), so a
    /// backdrop made or destroyed at the style recalc is a top layer change
    /// of its own, and its own topLayerElementsUpdated (Chrome 157's trace).
    backdrops: std.ArrayListUnmanaged(Backdrop) = .empty,
    /// Inside a DOM algorithm's probe (dom_events.zig sets it): nodes built
    /// now take their pseudo-elements from the record only - no style is
    /// resolved in the middle of a tree mutation; the next rendering update
    /// sends any the record lacks.
    in_probe: bool = false,
};

const PseudoRecord = struct {
    generation: u64,
    bits: dom.style.engine.GeneratedPseudos,
};

const CreationStack = struct {
    generation: u64,
    json: []u8,
};

const RefHold = dom.node_holds.RefHold;

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
    discardSearches(session);
    s.searches.deinit(session.allocator);
    s.searches = .empty;
    dropHistory(session);
    s.pending_slots.deinit(session.allocator);
    s.pending_slots = .empty;
    s.pending_adopted.deinit(session.allocator);
    s.pending_adopted = .empty;
    s.pseudo_state.deinit(session.allocator);
    s.pseudo_state = .empty;
    s.backdrops.deinit(session.allocator);
    s.backdrops = .empty;
    var stacks = s.creation_stacks.valueIterator();
    while (stacks.next()) |stack| session.allocator.free(stack.json);
    s.creation_stacks.deinit(session.allocator);
    s.creation_stacks = .empty;
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
    // EnableAndReset: a new history (and DOMEditor).
    dropHistory(session);
    const history = try session.allocator.create(dom_editor.History);
    history.* = .{ .allocator = session.allocator };
    s.history = history;
    if (session.side) |side| dom_events.register(side, session) catch |err| {
        dropHistory(session);
        return err;
    };
    s.include_whitespace = if (params.includeWhitespace) |w| w == .all else false;
    s.enabled = true;
    // The ::backdrops there already are no change (nothing is sent for what
    // was in the top layer before the agent was).
    s.backdrops.clearRetainingCapacity();
    if (session.arena) |arena| {
        for (inspectedDocuments(session, arena) catch &.{}) |document| _ = updateBackdrops(session, document);
    }
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
    // history_.Clear(): every node an edit held is let go.
    dropHistory(session);
    return .{};
}

/// DiscardFrontendBindings: the client forgets every node, and the pending
/// style revalidation is stopped (revalidate_task_->Reset()).
fn discardBindings(session: *PageSession) void {
    const s = &session.states.DOM;
    if (s.history) |history| history.reset();
    s.pending_slots.clearRetainingCapacity();
    s.pseudo_state.clearRetainingCapacity();
    s.pseudo_state_guard.reset();
    discardSearches(session);
    if (s.map) |map| map.clear();
    resetRevalidation(session);
}

fn dropHistory(session: *PageSession) void {
    const s = &session.states.DOM;
    const history = s.history orelse return;
    history.deinit();
    session.allocator.destroy(history);
    s.history = null;
}

/// search_results_.clear(): every search's holds let go.
fn discardSearches(session: *PageSession) void {
    const s = &session.states.DOM;
    for (s.searches.keys(), s.searches.values()) |key, holds| {
        releaseHolds(session, holds);
        session.allocator.free(key);
    }
    s.searches.clearRetainingCapacity();
}

fn releaseHolds(session: *PageSession, holds: []RefHold) void {
    for (holds) |*hold| hold.release();
    session.allocator.free(holds);
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
    const described = try buildNode(session, arena_state.allocator(), node, depth, params.pierce orelse false, .{});
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
    discardBindings(session);
    var depth = params.depth orelse 2;
    if (depth == -1) depth = std.math.maxInt(i64);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const root = try buildNode(session, arena_state.allocator(), document, depth, params.pierce orelse false, .{ .bindings = &map.document });
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
// Reading and pushing nodes (lane cdpd1, batch 2)
// ============================================================================

/// The bound element `node_id` (AssertElement: "Node is not an Element").
fn elementNamed(session: *PageSession, node_id: i64) !*runtime.Instance {
    const node = try nodeNamed(session, node_id, null, null);
    if ((interfaces.Node.get_nodeType(node) catch 0) != 1) return session.fail("Node is not an Element");
    return node;
}

/// InspectorDOMAgent::getAttributes.
pub fn getAttributes(session: *PageSession, params: D.getAttributes.Params) !D.getAttributes.Result {
    const element = try elementNamed(session, params.nodeId);
    return .{ .attributes = (try attributesOf(session.arena.?, element)) orelse &.{} };
}

/// InspectorDOMAgent::requestNode: the node a remote object names, its path
/// pushed (a detached one with its tree's root).
pub fn requestNode(session: *PageSession, params: D.requestNode.Params) !D.requestNode.Result {
    if (comptime !have_remote_objects) return session.fail("Could not find node with given id");
    const node = try nodeOfObject(session, params.objectId);
    return .{ .nodeId = try pushNodePath(session, node) };
}

/// InspectorDOMAgent::pushNodeByPathToFrontend (NodeForPath).
pub fn pushNodeByPathToFrontend(session: *PageSession, params: D.pushNodeByPathToFrontend.Params) !D.pushNodeByPathToFrontend.Result {
    if (!session.states.DOM.enabled) return session.fail("DOM agent is not enabled");
    const node = nodeForPath(session, params.path) orelse return session.fail("No node with given path found");
    return .{ .nodeId = try pushNodePath(session, node) };
}

/// NodeForPath: "1,HTML,2,BODY,1,DIV" - an inner child's index and its
/// nodeName, interleaved; the index "a" is an author shadow root ("u" a
/// user-agent one, which no page node has here), "d" a frame owner's
/// content document. From the agent's document.
fn nodeForPath(session: *PageSession, path: []const u8) ?*runtime.Instance {
    var node = topDocument(session) orelse return null;
    // SplitSkippingEmpty(',').
    var tokens: [512][]const u8 = undefined;
    var count: usize = 0;
    var it = std.mem.tokenizeScalar(u8, path, ',');
    while (it.next()) |token| {
        if (count == tokens.len) return null;
        tokens[count] = token;
        count += 1;
    }
    if (count == 0) return null;
    var i: usize = 0;
    while (i + 1 < count) : (i += 2) {
        const index_value = tokens[i];
        const child_name = tokens[i + 1];
        // StringToUintLoose: surrounding whitespace allowed.
        const parsed = std.fmt.parseInt(u32, std.mem.trim(u8, index_value, " \t\n\r\x0c"), 10) catch null;
        const child_number: u32 = parsed orelse 0;
        var child: ?*runtime.Instance = undefined;
        if (parsed == null) {
            if (std.mem.eql(u8, index_value, "d")) {
                child = if (contentNavigableOf(session, node)) |bc| frames.documentOf(bc) else null;
            } else if (std.mem.eql(u8, index_value, "a")) {
                child = if ((interfaces.Node.get_nodeType(node) catch 0) == 1) dom.shadow_hosts.rootForHost(node) else null;
            } else {
                child = null;
            }
        } else {
            var inner_count: u32 = 0;
            var c = innerFirstChild(session, node);
            while (c) |n| : (c = innerNextSibling(session, n)) inner_count += 1;
            if (child_number >= inner_count) return null;
            child = innerFirstChild(session, node);
        }
        var j: u32 = 0;
        while (child != null and j < child_number) : (j += 1) child = innerNextSibling(session, child.?);
        const found = child orelse return null;
        var name = interfaces.Node.get_nodeName(found) catch return null;
        defer name.deinit(found.ctx.allocator);
        if (!std.mem.eql(u8, name.asSlice(), child_name)) return null;
        node = found;
    }
    return node;
}

/// InspectorDOMAgent::pushNodesByBackendIdsToFrontend: each node of the
/// inspected frames pushed (a detached one too), 0 for any other.
pub fn pushNodesByBackendIdsToFrontend(session: *PageSession, params: D.pushNodesByBackendIdsToFrontend.Params) !D.pushNodesByBackendIdsToFrontend.Result {
    const document = topDocument(session);
    const bound = if (session.states.DOM.map) |map| (if (document) |d| map.boundId(d) != 0 else false) else false;
    if (!session.states.DOM.enabled or !bound) return session.fail("Document needs to be requested first");
    const ids = nodeIds(session) orelse return error.OutOfMemory;
    const out = try session.arena.?.alloc(i64, params.backendNodeIds.len);
    for (params.backendNodeIds, out) |backend_id, *node_id| {
        node_id.* = 0;
        const node = ids.nodeOf(backend_id) orelse continue;
        const owner = nodeDocumentOf(node) orelse continue;
        if (frameOfDocument(session, owner) == null) continue;
        node_id.* = try pushNodePath(session, node);
    }
    return .{ .nodeIds = out };
}

/// A node's node document (a document's own).
fn nodeDocumentOf(node: *runtime.Instance) ?*runtime.Instance {
    if ((interfaces.Node.get_nodeType(node) catch 0) == 9) return node;
    return interfaces.Node.get_ownerDocument(node) catch null;
}

/// InspectorDOMAgent::getFlattenedDocument: the bindings discarded, the
/// document built to `depth` (-1: all) into a flat list - each node after
/// what was built under it, with its parentId - and the document last.
pub fn getFlattenedDocument(session: *PageSession, params: D.getFlattenedDocument.Params, reply: Reply(D.getFlattenedDocument)) !void {
    if (!session.states.DOM.enabled) return session.fail("DOM agent hasn't been enabled");
    const document = topDocument(session) orelse return session.fail("Document is not available");
    discardBindings(session);
    const map = try mapOf(session);
    var depth = params.depth orelse -1;
    if (depth == -1) depth = std.math.maxInt(i64);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var nodes: std.ArrayListUnmanaged(D.Node) = .empty;
    const root = try buildNode(session, arena, document, depth, params.pierce orelse false, .{ .bindings = &map.document, .flatten = &nodes });
    try nodes.append(arena, root);
    reply.ok(.{ .nodes = nodes.items });
}

/// InspectorDOMAgent::collectClassNamesFromSubtree: every class of the
/// elements in the node's flat tree (FlatTreeTraversal), once each.
pub fn collectClassNamesFromSubtree(session: *PageSession, params: D.collectClassNamesFromSubtree.Params) !D.collectClassNamesFromSubtree.Result {
    const map = session.states.DOM.map orelse return session.fail("No suitable node with given id found");
    const root = map.nodeOf(params.nodeId) orelse return session.fail("No suitable node with given id found");
    const root_type = interfaces.Node.get_nodeType(root) catch 0;
    if (root_type != 1 and root_type != 9 and root_type != 11) return session.fail("No suitable node with given id found");
    const arena = session.arena.?;
    var names: std.StringArrayHashMapUnmanaged(void) = .empty;
    var stack: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    try stack.append(arena, root);
    while (stack.pop()) |node| {
        if ((interfaces.Node.get_nodeType(node) catch 0) == 1) try addClassNames(arena, node, &names);
        try appendFlatChildren(arena, node, &stack);
    }
    return .{ .classNames = names.keys() };
}

/// `element`'s classes (its class attribute split on ASCII whitespace;
/// folded to lowercase in a quirks-mode document, Blink's ShouldFoldCase).
fn addClassNames(arena: Allocator, element: *runtime.Instance, names: *std.StringArrayHashMapUnmanaged(void)) !void {
    const count = dom.element_attributes.count(element);
    for (0..count) |i| {
        const attribute = dom.element_attributes.at(element, i) orelse continue;
        if (attribute.namespace != null or !std.mem.eql(u8, attribute.local_name, "class")) continue;
        const quirks = if (nodeDocumentOf(element)) |document| (compatibilityModeOf(document) orelse .NoQuirksMode) == .QuirksMode else false;
        var it = std.mem.tokenizeAny(u8, attribute.value, " \t\n\r\x0c");
        while (it.next()) |token| {
            const name = if (quirks) try std.ascii.allocLowerString(arena, token) else try arena.dupe(u8, token);
            try names.put(arena, name, {});
        }
        return;
    }
}

/// The node's children in the flat tree, onto `stack`: a shadow host's
/// shadow root's children, a slot's assigned nodes (its own children when it
/// has none), any other node's children (CSS Scoping 2.1; Blink's
/// FlatTreeTraversal).
fn appendFlatChildren(arena: Allocator, node: *runtime.Instance, stack: *std.ArrayListUnmanaged(*runtime.Instance)) !void {
    var parent = node;
    if ((interfaces.Node.get_nodeType(node) catch 0) == 1) {
        if (dom.shadow_hosts.rootForHost(node)) |root| parent = root;
        if (parent == node) {
            if (dom.instance_bridge.getNodeBase(node)) |base| if (dom.slot_helpers.slotState(base)) |slot| {
                if (slot.hasAssignedNodes()) {
                    for (slot.assigned_nodes.items) |ref| {
                        const assigned = ref.get() orelse continue;
                        const instance = assigned.registeredInstance() orelse continue;
                        try stack.append(arena, instance);
                    }
                    return;
                }
            };
        }
    }
    var child = interfaces.Node.get_firstChild(parent) catch null;
    while (child) |c| : (child = interfaces.Node.get_nextSibling(c) catch null) try stack.append(arena, c);
}

/// The documents of the session's tab's frames, the top one first
/// (Blink's InspectorDOMAgent::Documents over InspectedFrames).
fn inspectedDocuments(session: *PageSession, arena: Allocator) ![]*runtime.Instance {
    var out: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    const top = frames.navigable(session, session.tab) orelse return out.items;
    try appendDocuments(arena, top, &out);
    return out.items;
}

fn appendDocuments(arena: Allocator, bc: *frames.BrowsingContext, out: *std.ArrayListUnmanaged(*runtime.Instance)) !void {
    if (frames.documentOf(bc)) |document| try out.append(arena, document);
    for (bc.children.items) |child| {
        if (child.is_closed) continue;
        try appendDocuments(arena, child, out);
    }
}

/// InspectorDOMAgent::getTopLayerElements: each inspected document's top
/// layer, in order, each element's path pushed (0s left out).
pub fn getTopLayerElements(session: *PageSession, params: D.getTopLayerElements.Params) !D.getTopLayerElements.Result {
    _ = params;
    if (!session.states.DOM.enabled) return session.fail("DOM agent hasn't been enabled");
    const arena = session.arena.?;
    var out: std.ArrayListUnmanaged(i64) = .empty;
    for (try inspectedDocuments(session, arena)) |document| {
        const layer = (dom.top_layer.ofDocument(document, false) catch null) orelse continue;
        var members: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
        for (layer.entries.items) |entry| {
            if (!(entry.showing or entry.modal or entry.fullscreen)) continue;
            const element = entry.node() orelse continue;
            // An element is in the top layer once, where it was last added.
            for (members.items, 0..) |m, i| if (m == element) {
                _ = members.orderedRemove(i);
                break;
            };
            try members.append(arena, element);
        }
        for (members.items) |element| {
            const id = try pushNodePath(session, element);
            if (id != 0) try out.append(arena, id);
        }
    }
    return .{ .nodeIds = out.items };
}

/// InspectorDOMAgent::performSearch: the documents searched now (dom_search
/// .zig), the results held under a new search id.
pub fn performSearch(session: *PageSession, params: D.performSearch.Params) !D.performSearch.Result {
    const s = &session.states.DOM;
    if (!s.enabled) return session.fail("DOM agent is not enabled");
    const arena = session.arena.?;
    var results: dom_search.Results = .{};
    defer results.deinit(session.allocator);
    try dom_search.search(session.allocator, try inspectedDocuments(session, arena), params.query, params.includeUserAgentShadowDOM orelse false, &results);
    const holds = try session.allocator.alloc(RefHold, results.nodes.items.len);
    for (results.nodes.items, holds) |node, *hold| {
        hold.* = .{};
        hold.set(node);
    }
    errdefer releaseHolds(session, holds);
    s.last_search += 1;
    const token: u64 = if (session.side) |side| side.token % 100000 else 0;
    const id = try std.fmt.allocPrint(session.allocator, "{d}.{d}", .{ token, s.last_search });
    errdefer session.allocator.free(id);
    try s.searches.put(session.allocator, id, holds);
    return .{ .searchId = try arena.dupe(u8, id), .resultCount = @intCast(holds.len) };
}

/// InspectorDOMAgent::getSearchResults: results [fromIndex, toIndex), each
/// path pushed.
pub fn getSearchResults(session: *PageSession, params: D.getSearchResults.Params) !D.getSearchResults.Result {
    const holds = session.states.DOM.searches.get(params.searchId) orelse return session.fail("No search session with given id found");
    const size: i64 = @intCast(holds.len);
    if (params.fromIndex < 0 or params.toIndex > size or params.fromIndex >= params.toIndex) return session.fail("Invalid search result range");
    const from: usize = @intCast(params.fromIndex);
    const to: usize = @intCast(params.toIndex);
    const out = try session.arena.?.alloc(i64, to - from);
    for (holds[from..to], out) |*hold, *node_id| {
        const node = hold.hold.get() orelse {
            node_id.* = 0;
            continue;
        };
        node_id.* = try pushNodePath(session, node);
    }
    return .{ .nodeIds = out };
}

/// InspectorDOMAgent::discardSearchResults: the search's holds let go.
pub fn discardSearchResults(session: *PageSession, params: D.discardSearchResults.Params) !D.discardSearchResults.Result {
    const s = &session.states.DOM;
    if (s.searches.fetchOrderedRemove(params.searchId)) |entry| {
        releaseHolds(session, entry.value);
        session.allocator.free(entry.key);
    }
    return .{};
}

/// InspectorDOMAgent::focus: a focusable element is focused by the focus()
/// method steps as for a user's gesture (Element::Focus with
/// FocusTrigger::kUserGesture: the focus-without-user-activation check does
/// not apply; html.focus.focusForUserGesture).
pub fn focus(session: *PageSession, params: D.focus.Params) !D.focus.Result {
    const node = try nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
    if ((interfaces.Node.get_nodeType(node) catch 0) != 1) return session.fail("Node is not an Element");
    const html = @import("html");
    if (!html.focus.isFocusableArea(node)) return session.fail("Element is not focusable");
    html.focus.focusForUserGesture(node);
    return .{};
}

/// InspectorDOMAgent::setFileInputFiles: the files at the host's paths
/// become the input's selection - Blink's HTMLInputElement::SetFilesFromPaths
/// (html.file_selection: the platform's userFile / userDirectory, File's
/// constructor, the files setter, then input and change, or cancel when
/// nothing changed), before the answer, as Blink's synchronous call.
pub fn setFileInputFiles(session: *PageSession, params: D.setFileInputFiles.Params) !D.setFileInputFiles.Result {
    const node = try nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
    const is_file_input = node.implements(interfaces.HTMLInputElement.State) and
        std.mem.eql(u8, (interfaces.HTMLInputElement.get_type(node) catch runtime.DOMString.initEmpty()).asSlice(), "file");
    if (!is_file_input) return session.fail("Node is not a file input element");
    if (comptime @import("platform").capabilities.file_picker == .unsupported) return .{};
    try @import("html").file_selection.setFilesFromPaths(node, params.files);
    return .{};
}

/// InspectorDOMAgent::getContainerForNode: the element's query container
/// for the name, axes and types asked (dom.style.engine.findQueryContainer:
/// Blink's StyleResolver::FindContainerForElement), its path pushed; none
/// when no ancestor qualifies.
pub fn getContainerForNode(session: *PageSession, params: D.getContainerForNode.Params) !D.getContainerForNode.Result {
    const element = try elementNamed(session, params.nodeId);
    var request: dom.style.engine.ContainerRequest = .{
        .name = params.containerName orelse "",
        .scroll_state = params.queriesScrollState orelse false,
        .anchored = params.queriesAnchored orelse false,
    };
    if (params.physicalAxes) |axes| switch (axes) {
        .Horizontal => request.physical_horizontal = true,
        .Vertical => request.physical_vertical = true,
        .Both => {
            request.physical_horizontal = true;
            request.physical_vertical = true;
        },
    };
    if (params.logicalAxes) |axes| switch (axes) {
        .Inline => request.logical_inline = true,
        .Block => request.logical_block = true,
        .Both => {
            request.logical_inline = true;
            request.logical_block = true;
        },
    };
    const container = dom.style.engine.findQueryContainer(element, request) orelse return .{};
    return .{ .nodeId = try pushNodePath(session, container) };
}

/// InspectorDOMAgent::getQueryingDescendantsForContainer: the element's
/// descendants (ElementTraversal, tree order) whose matched @container rules
/// query it (dom.style.engine.queriesContainer: ContainerQueriedByElement),
/// each path pushed.
pub fn getQueryingDescendantsForContainer(session: *PageSession, params: D.getQueryingDescendantsForContainer.Params) !D.getQueryingDescendantsForContainer.Result {
    const container = try elementNamed(session, params.nodeId);
    const map = try mapOf(session);
    const arena = session.arena.?;
    var out: std.ArrayListUnmanaged(i64) = .empty;
    var stack: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    var child = interfaces.Node.get_lastChild(container) catch null;
    while (child) |c| : (child = interfaces.Node.get_previousSibling(c) catch null) try stack.append(arena, c);
    while (stack.pop()) |node| {
        if ((interfaces.Node.get_nodeType(node) catch 0) != 1) continue;
        if (dom.style.engine.queriesContainer(node, container)) try out.append(arena, try pushNodePathIn(session, node, &map.document));
        var c = interfaces.Node.get_lastChild(node) catch null;
        while (c) |n| : (c = interfaces.Node.get_previousSibling(n) catch null) try stack.append(arena, n);
    }
    return .{ .nodeIds = out.items };
}

/// InspectorDOMAgent::setNodeStackTracesEnabled.
pub fn setNodeStackTracesEnabled(session: *PageSession, params: D.setNodeStackTracesEnabled.Params) !D.setNodeStackTracesEnabled.Result {
    session.states.DOM.capture_node_stack_traces = params.enable;
    return .{};
}

/// InspectorDOMAgent::getNodeStackTraces: the bound node's creation stack,
/// if one was captured (none for a node made with no script running).
pub fn getNodeStackTraces(session: *PageSession, params: D.getNodeStackTraces.Params, reply: Reply(D.getNodeStackTraces)) !void {
    const node = try nodeNamed(session, params.nodeId, null, null);
    const s = &session.states.DOM;
    const stack = s.creation_stacks.get(@intFromPtr(node)) orelse return reply.okRaw("{}");
    if (stack.generation != runtime.SlabAllocator.generationOf(node)) return reply.okRaw("{}");
    var out: std.Io.Writer.Allocating = .init(session.allocator);
    defer out.deinit();
    try out.writer.print("{{\"creation\":{s}}}", .{stack.json});
    reply.okRaw(out.written());
}

/// NodeCreated: with stack traces on, the running script's full stack
/// (SourceLocation::CaptureWithFullStackTrace: V8's 200 frames), kept for
/// the node.
pub fn nodeCreated(session: *PageSession, node: *runtime.Instance) void {
    if (comptime !contexts.have_inspector) return;
    const s = &session.states.DOM;
    if (!s.capture_node_stack_traces) return;
    const browser = session.browser orelse return;
    const agent = browser.agent orelse return;
    const json = (engine.inspectorStackTrace(agent, 200, session.allocator) catch return) orelse return;
    if (s.creation_stacks.count() >= s.creation_sweep_at) sweepCreationStacks(session);
    s.creation_stacks_guard.beforeInsert(&s.creation_stacks);
    const entry = s.creation_stacks.getOrPut(session.allocator, @intFromPtr(node)) catch {
        session.allocator.free(json);
        return;
    };
    if (entry.found_existing) session.allocator.free(entry.value_ptr.json);
    entry.value_ptr.* = .{ .generation = runtime.SlabAllocator.generationOf(node), .json = json };
}

/// Drop the stacks of nodes that are gone (the weak map's sweep), and let
/// the map grow to twice what is left before the next.
fn sweepCreationStacks(session: *PageSession) void {
    const s = &session.states.DOM;
    var dead: std.ArrayListUnmanaged(usize) = .empty;
    defer dead.deinit(session.allocator);
    var it = s.creation_stacks.iterator();
    while (it.next()) |entry| {
        const node: *runtime.Instance = @ptrFromInt(entry.key_ptr.*);
        if (runtime.SlabAllocator.generationOf(node) != entry.value_ptr.generation) dead.append(session.allocator, entry.key_ptr.*) catch break;
    }
    for (dead.items) |key| {
        if (s.creation_stacks.fetchRemove(key)) |removed| {
            session.allocator.free(removed.value.json);
            s.creation_stacks_guard.noteRemoval(&s.creation_stacks);
        }
    }
    s.creation_sweep_at = @max(1024, s.creation_stacks.count() * 2);
}

// ============================================================================
// Editing (lane cdpd1, batch 3): DOMEditor's actions through the history
// ============================================================================

/// The agent's editor over its history (made with the agent; an agent not
/// enabled has no bound nodes to edit).
fn editorOf(session: *PageSession) !dom_editor.Editor {
    const history = session.states.DOM.history orelse return session.fail("DOM agent hasn't been enabled");
    return .{ .allocator = session.allocator, .history = history };
}

/// An edit's DOM exception, as InspectorDOMAgent::ToResponse words it.
fn editFailed(session: *PageSession, editor: *const dom_editor.Editor, err: dom_editor.Error) anyerror {
    if (err == error.OutOfMemory) return err;
    const failure = editor.failure;
    if (failure.message.len == 0) return session.fail(failure.name);
    const text = std.mem.concat(session.arena.?, u8, &.{ failure.name, " ", failure.message }) catch return error.OutOfMemory;
    return session.fail(text);
}

/// AssertEditableNode: a bound node that is not a shadow root (nor in a
/// user-agent shadow tree, nor a pseudo-element: neither exists here).
fn editableNode(session: *PageSession, node_id: i64) !*runtime.Instance {
    const node = try nodeNamed(session, node_id, null, null);
    if (node.implements(interfaces.ShadowRoot.State)) return session.fail("Cannot edit shadow roots");
    return node;
}

/// AssertEditableElement.
fn editableElement(session: *PageSession, node_id: i64) !*runtime.Instance {
    return elementNamed(session, node_id);
}

/// AssertEditableChildNode: an editable node that is `parent`'s child.
fn editableChild(session: *PageSession, parent: *runtime.Instance, node_id: i64) !*runtime.Instance {
    const node = try editableNode(session, node_id);
    if ((interfaces.Node.get_parentNode(node) catch null) != parent) return session.fail("Anchor node must be child of the target element");
    return node;
}

/// InspectorDOMAgent::setAttributeValue.
pub fn setAttributeValue(session: *PageSession, params: D.setAttributeValue.Params) !D.setAttributeValue.Result {
    const element = try editableElement(session, params.nodeId);
    var editor = try editorOf(session);
    editor.setAttribute(element, params.name, params.value) catch |err| return editFailed(session, &editor, err);
    return .{};
}

/// InspectorDOMAgent::removeAttribute.
pub fn removeAttribute(session: *PageSession, params: D.removeAttribute.Params) !D.removeAttribute.Result {
    const element = try editableElement(session, params.nodeId);
    var editor = try editorOf(session);
    editor.removeAttribute(element, params.name) catch |err| return editFailed(session, &editor, err);
    return .{};
}

/// InspectorDOMAgent::setAttributesAsText: `text` parsed as the attributes
/// of an element like this one (`<span TEXT>`, `<svg TEXT>` for an SVG
/// element, `<math TEXT>` for MathML), in the context of its owner svg or
/// the body; each attribute set; `name`, when it was not among them,
/// removed.
pub fn setAttributesAsText(session: *PageSession, params: D.setAttributesAsText.Params) !D.setAttributesAsText.Result {
    const element = try editableElement(session, params.nodeId);
    const arena = session.arena.?;
    const document = nodeDocumentOf(element) orelse return session.fail("Could not parse value as attributes");
    const is_html_document = dom.document_internals.getDocumentType(document) != .xml;
    const namespace = namespaceOf(arena, element);
    const is_svg = std.mem.eql(u8, namespace, "http://www.w3.org/2000/svg");
    const is_mathml = std.mem.eql(u8, namespace, "http://www.w3.org/1998/Math/MathML");
    // "Not all elements can represent the context (e.g. <iframe>). Use the
    // owner <svg> element if there is any, falling back to <body>."
    var context: ?*runtime.Instance = null;
    if (is_svg) context = interfaces.SVGElement.get_ownerSVGElement(element) catch null;
    if (context == null and is_html_document) context = interfaces.Document.get_body(document) catch null;
    if (context == null and !is_html_document) context = interfaces.Document.get_documentElement(document) catch null;
    const markup = try std.mem.concat(arena, u8, if (is_svg) &.{ "<svg ", params.text, "></svg>" } else if (is_mathml) &.{ "<math ", params.text, "></math>" } else &.{ "<span ", params.text, "></span>" });
    const html = @import("html");
    const fragment = html.dom_parser.parseFragmentIn(document.ctx.allocator, document.ctx, markup, context, .inert) catch return session.fail("Could not parse value as attributes");
    const fragment_generation = runtime.SlabAllocator.generationOf(fragment);
    defer dom.node_creation.releaseIfUnwrapped(fragment, fragment_generation);
    const parsed = (interfaces.Node.get_firstChild(fragment) catch null) orelse return session.fail("Could not parse value as attributes");
    if ((interfaces.Node.get_nodeType(parsed) catch 0) != 1) return session.fail("Could not parse value as attributes");

    const ignore_case = is_html_document and std.mem.eql(u8, namespace, "http://www.w3.org/1999/xhtml");
    const name: ?[]const u8 = if (params.name) |n| (if (ignore_case) try std.ascii.allocLowerString(arena, n) else n) else null;
    var editor = try editorOf(session);
    const count = dom.element_attributes.count(parsed);
    if (count == 0 and name != null) {
        editor.removeAttribute(element, name.?) catch |err| return editFailed(session, &editor, err);
        return .{};
    }
    var found_original = false;
    for (0..count) |i| {
        const attribute = dom.element_attributes.at(parsed, i) orelse continue;
        var attribute_name = try qualifiedName(arena, attribute.prefix, attribute.local_name);
        if (ignore_case) attribute_name = try std.ascii.allocLowerString(arena, attribute_name);
        if (name) |n| found_original = found_original or std.mem.eql(u8, attribute_name, n);
        const value = try arena.dupe(u8, attribute.value);
        editor.setAttribute(element, attribute_name, value) catch |err| return editFailed(session, &editor, err);
    }
    if (!found_original and params.name != null and std.mem.trim(u8, params.name.?, " \t\n\r\x0c").len > 0) {
        editor.removeAttribute(element, name.?) catch |err| return editFailed(session, &editor, err);
    }
    return .{};
}

fn namespaceOf(arena: Allocator, element: *runtime.Instance) []const u8 {
    var ns = (interfaces.Element.get_namespaceURI(element) catch null) orelse return "";
    defer ns.deinit(element.ctx.allocator);
    return arena.dupe(u8, ns.asSlice()) catch "";
}

/// InspectorDOMAgent::setNodeValue (157: text and processing instruction
/// nodes).
pub fn setNodeValue(session: *PageSession, params: D.setNodeValue.Params) !D.setNodeValue.Result {
    const node = try editableNode(session, params.nodeId);
    const node_type = interfaces.Node.get_nodeType(node) catch 0;
    if (node_type != 3 and node_type != 7) return session.fail("Can only set value of text nodes or processing instructions");
    var editor = try editorOf(session);
    editor.setNodeValue(node, params.value) catch |err| return editFailed(session, &editor, err);
    return .{};
}

/// InspectorDOMAgent::removeNode.
pub fn removeNode(session: *PageSession, params: D.removeNode.Params) !D.removeNode.Result {
    const node = try editableNode(session, params.nodeId);
    const parent = (interfaces.Node.get_parentNode(node) catch null) orelse return session.fail("Cannot remove detached node");
    var editor = try editorOf(session);
    editor.removeChild(parent, node) catch |err| return editFailed(session, &editor, err);
    return .{};
}

/// InspectorDOMAgent::setNodeName (157): an element becomes a new element
/// of that name with its attributes and children; a processing instruction
/// a new one with that target and its data. The new node takes its place,
/// is pushed, and is sent its children when the client had the old one's.
pub fn setNodeName(session: *PageSession, params: D.setNodeName.Params) !D.setNodeName.Result {
    const old_node = try nodeNamed(session, params.nodeId, null, null);
    const document = nodeDocumentOf(old_node) orelse return session.fail("Not an element");
    var editor = try editorOf(session);
    var name = try runtime.DOMString.initDupe(session.allocator, params.name);
    defer name.deinit(session.allocator);
    const new_node = switch (interfaces.Node.get_nodeType(old_node) catch 0) {
        1 => blk: {
            const new_element = interfaces.Document.call_createElement(document, name, .notPassed()) catch |err| {
                if (err == error.InvalidCharacterError) return session.fail(try std.mem.concat(session.arena.?, u8, &.{ "InvalidCharacterError The tag name provided ('", params.name, "') is not a valid name." }));
                return session.fail(@errorName(err));
            };
            dom.element_attributes.cloneFrom(new_element, old_node) catch return error.OutOfMemory;
            while (interfaces.Node.get_firstChild(old_node) catch null) |child| {
                editor.insertBefore(new_element, child, null) catch |err| return editFailed(session, &editor, err);
            }
            break :blk new_element;
        },
        7 => blk: {
            var data = (interfaces.Node.get_nodeValue(old_node) catch null) orelse runtime.DOMString.initEmpty();
            defer data.deinit(old_node.ctx.allocator);
            break :blk interfaces.Document.call_createProcessingInstruction(document, name, data) catch |err| return session.fail(@errorName(err));
        },
        else => return session.fail("Not an element"),
    };
    const parent = (interfaces.Node.get_parentNode(old_node) catch null) orelse return session.fail("Cannot remove detached node");
    const next = interfaces.Node.get_nextSibling(old_node) catch null;
    editor.insertBefore(parent, new_node, next) catch |err| return editFailed(session, &editor, err);
    editor.removeChild(parent, old_node) catch |err| return editFailed(session, &editor, err);
    const new_id = try pushNodePath(session, new_node);
    if (session.states.DOM.map) |map| if (map.childrenRequested(params.nodeId)) try pushChildNodes(session, new_id, 1, false);
    return .{ .nodeId = new_id };
}

/// InspectorDOMAgent::setOuterHTML: node 0 patches the document itself
/// (with the agent's own editor); any other editable node is patched by a
/// SetOuterHTML action (dom_patch.zig, DOMPatchSupport), the node that took
/// its place pushed, and sent its children when the client had the old
/// node's.
pub fn setOuterHTML(session: *PageSession, params: D.setOuterHTML.Params) !D.setOuterHTML.Result {
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    var editor = try editorOf(session);
    if (params.nodeId == 0) {
        const document = topDocument(session) orelse return session.fail("Document is not available");
        var patch: dom_patch.Patch = .{ .arena = arena_state.allocator(), .editor = &editor, .document = document };
        patch.patchDocument(params.outerHTML) catch |err| return editFailed(session, &editor, err);
        return .{};
    }
    const node = try editableNode(session, params.nodeId);
    const document = nodeDocumentOf(node) orelse return session.fail("Not an HTML/XML document");
    const Context = struct { arena: Allocator, document: *runtime.Instance, markup: []const u8 };
    const context: Context = .{ .arena = arena_state.allocator(), .document = document, .markup = params.outerHTML };
    const new_node = editor.setOuterHTML(node, context, struct {
        fn patch(ctx: Context, nested: *dom_editor.Editor, target: *runtime.Instance) dom_editor.Error!?*runtime.Instance {
            // SetOuterHTMLAction::Perform: "if (!document->documentElement())
            // return false" - no change, and no error.
            if ((interfaces.Document.get_documentElement(ctx.document) catch null) == null) return null;
            var p: dom_patch.Patch = .{ .arena = ctx.arena, .editor = nested, .document = ctx.document };
            return p.patchNode(target, ctx.markup);
        }
    }.patch) catch |err| return editFailed(session, &editor, err);
    // "The only child node has been deleted."
    const placed = new_node orelse return .{};
    const new_id = try pushNodePath(session, placed);
    if (session.states.DOM.map) |map| if (map.childrenRequested(params.nodeId)) try pushChildNodes(session, new_id, 1, false);
    return .{};
}

/// The target element and anchor of moveTo / copyTo.
fn insertionPoint(session: *PageSession, target_id: i64, anchor_id: ?i64) !struct { target: *runtime.Instance, anchor: ?*runtime.Instance } {
    const target = try editableElement(session, target_id);
    const anchor: ?*runtime.Instance = if (anchor_id) |id| (if (id != 0) try editableChild(session, target, id) else null) else null;
    return .{ .target = target, .anchor = anchor };
}

/// InspectorDOMAgent::moveTo.
pub fn moveTo(session: *PageSession, params: D.moveTo.Params) !D.moveTo.Result {
    const node = try editableNode(session, params.nodeId);
    const target = try editableElement(session, params.targetNodeId);
    var current: ?*runtime.Instance = target;
    while (current) |c| : (current = interfaces.Node.get_parentNode(c) catch null) {
        if (c == node) return session.fail("Unable to move node into self or descendant");
    }
    const point = try insertionPoint(session, params.targetNodeId, params.insertBeforeNodeId);
    var editor = try editorOf(session);
    editor.insertBefore(point.target, node, point.anchor) catch |err| return editFailed(session, &editor, err);
    return .{ .nodeId = try pushNodePath(session, node) };
}

/// InspectorDOMAgent::copyTo: a deep clone inserted.
pub fn copyTo(session: *PageSession, params: D.copyTo.Params) !D.copyTo.Result {
    const node = try editableNode(session, params.nodeId);
    const point = try insertionPoint(session, params.targetNodeId, params.insertBeforeNodeId);
    const clone = interfaces.Node.call_cloneNode(node, .passed(true)) catch return session.fail("Failed to clone node");
    var editor = try editorOf(session);
    editor.insertBefore(point.target, clone, point.anchor) catch |err| return editFailed(session, &editor, err);
    return .{ .nodeId = try pushNodePath(session, clone) };
}

/// InspectorDOMAgent::undo.
pub fn undo(session: *PageSession, params: D.undo.Params) !D.undo.Result {
    _ = params;
    if (!session.states.DOM.enabled) return session.fail("DOM agent is not enabled");
    var editor = try editorOf(session);
    editor.history.undo(&editor) catch |err| return editFailed(session, &editor, err);
    return .{};
}

/// InspectorDOMAgent::redo.
pub fn redo(session: *PageSession, params: D.redo.Params) !D.redo.Result {
    _ = params;
    if (!session.states.DOM.enabled) return session.fail("DOM agent is not enabled");
    var editor = try editorOf(session);
    editor.history.redo(&editor) catch |err| return editFailed(session, &editor, err);
    return .{};
}

/// InspectorDOMAgent::markUndoableState.
pub fn markUndoableState(session: *PageSession, params: D.markUndoableState.Params) !D.markUndoableState.Result {
    _ = params;
    if (!session.states.DOM.enabled) return session.fail("DOM agent is not enabled");
    try session.states.DOM.history.?.markUndoableState();
    return .{};
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
    const value = buildNode(session, arena_state.allocator(), node, 0, false, .{ .bindings = &map.document, .no_pseudos = true, .no_assigned_slot = true }) catch return;
    session.emit(D.childNodeInserted, .{ .parentNodeId = parent_id, .previousNodeId = previous_id, .node = value });
    // Its style, and with it its pseudo-elements, at the next rendering
    // update (Blink's insertion schedules a style recalc).
    if (nodeDocumentOf(node)) |document| dom.update_the_rendering.requestFrame(document);
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
    unbindRemoved(session, map, node);
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
    // Its style may change, and its pseudo-elements with it, at the next
    // rendering update (Blink's attribute change schedules a style recalc).
    if (nodeDocumentOf(element)) |document| dom.update_the_rendering.requestFrame(document);
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
    scheduleRevalidation(session, element);
}

/// The revalidation task's timer: started, if it is not, on `node`'s event
/// loop (StartOneShot(0) on the DOM manipulation task runner).
fn scheduleRevalidation(session: *PageSession, node: *runtime.Instance) void {
    const s = &session.states.DOM;
    if (s.revalidate != null) return;
    const loop = node.ctx.getOptionalEventLoop() orelse return;
    const task = session.allocator.create(RevalidateTask) catch return;
    task.* = .{ .session = session, .allocator = session.allocator };
    s.revalidate = task;
    loop.queueTask(.{ .callback = RevalidateTask.run, .context = task, .drop = RevalidateTask.drop });
}

/// DidModifyAdoptedStyleSheets: the tree scope joins the pending set (bound
/// or not: AdoptedStyleSheetsInvalidated checks when the task runs).
pub fn didModifyAdoptedStyleSheets(session: *PageSession, owner: *runtime.Instance) void {
    const s = &session.states.DOM;
    if (s.map == null) return;
    for (s.pending_adopted.items) |pending| if (pending.get() == owner) return scheduleRevalidation(session, owner);
    s.pending_adopted.append(session.allocator, WeakNode.of(owner)) catch return;
    scheduleRevalidation(session, owner);
}

/// AdoptedStyleSheetsInvalidated, for each pending tree scope the client
/// has: adoptedStyleSheetsModified with its sheets' ids.
fn adoptedStyleSheetsInvalidated(session: *PageSession) void {
    const s = &session.states.DOM;
    defer s.pending_adopted.clearRetainingCapacity();
    const map = s.map orelse return;
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    for (s.pending_adopted.items) |pending| {
        const owner = pending.get() orelse continue;
        const id = map.boundId(owner);
        if (id == 0) continue;
        const sheets = adoptedSheetIds(session, arena_state.allocator(), owner) catch continue;
        session.emit(D.adoptedStyleSheetsModified, .{ .nodeId = id, .adoptedStyleSheets = sheets });
    }
}

/// The styleSheetIds of `owner`'s adopted sheets, in order.
fn adoptedSheetIds(session: *PageSession, arena: Allocator, owner: *runtime.Instance) ![]const []const u8 {
    const browser = session.browser orelse return &.{};
    const registry = try browser.scope.of(StyleSheetIds);
    const token: u64 = if (session.side) |side| side.token else 0;
    var out: std.ArrayListUnmanaged([]const u8) = .empty;
    for (dom.style.adopted.sheetsOf(owner)) |sheet| {
        const object = sheet.get() orelse continue;
        try out.append(arena, try registry.idOf(arena, token, object));
    }
    return out.items;
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
        // InspectorRevalidateDOMTask::OnTimer: the style attributes, then
        // each adopted sheets change.
        styleAttributeInvalidated(session);
        adoptedStyleSheetsInvalidated(session);
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
    s.pending_adopted.clearRetainingCapacity();
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
    const value = buildNode(session, arena_state.allocator(), root, 0, false, .{ .bindings = &map.document }) catch return;
    session.emit(D.shadowRootPushed, .{ .hostId = host_id, .root = value });
}

/// A bound slot's assigned nodes changed: kept for the next rendering
/// update, which is asked for.
pub fn slotAssignmentChanged(session: *PageSession, slot: *runtime.Instance) void {
    const s = &session.states.DOM;
    const map = s.map orelse return;
    if (map.boundId(slot) == 0) return;
    for (s.pending_slots.items) |pending| if (pending.get() == slot) return;
    s.pending_slots.append(session.allocator, WeakNode.of(slot)) catch return;
    if (nodeDocumentOf(slot)) |document| dom.update_the_rendering.requestFrame(document);
}

/// The document's rendering update (Blink's lifecycle update): each pending
/// slot of it the client still has gets DidPerformSlotDistribution -
/// distributedNodesUpdated with its assigned nodes.
pub fn renderingUpdated(session: *PageSession, document: *runtime.Instance) void {
    const changes = updateBackdrops(session, document);
    // A backdrop made enters the top layer as the recalc makes it, before
    // its PseudoElementCreated; one destroyed leaves after its
    // PseudoElementDestroyed (Chrome 157's order).
    for (0..changes.added) |_| topLayerElementsChanged(session, document);
    updatePseudoElements(session, document);
    for (0..changes.removed) |_| topLayerElementsChanged(session, document);
    sendDistributions(session, document);
}

/// A top layer element with a ::backdrop, by name.
const Backdrop = struct { document: usize, element: usize, generation: u64 };

/// The ::backdrops `document`'s top layer has now, against those it had at
/// the last rendering update: how many came and went. The record is updated.
fn updateBackdrops(session: *PageSession, document: *runtime.Instance) struct { added: usize, removed: usize } {
    const s = &session.states.DOM;
    var now: std.ArrayListUnmanaged(Backdrop) = .empty;
    defer now.deinit(session.allocator);
    if (dom.top_layer.ofDocument(document, false) catch null) |layer| {
        for (layer.entries.items) |entry| {
            if (!(entry.showing or entry.modal or entry.fullscreen)) continue;
            const element = entry.node() orelse continue;
            if (!dom.style.engine.generatedPseudos(element).backdrop) continue;
            const named: Backdrop = .{ .document = @intFromPtr(document), .element = @intFromPtr(element), .generation = runtime.SlabAllocator.generationOf(element) };
            if (indexOfBackdrop(now.items, named) == null) now.append(session.allocator, named) catch return .{ .added = 0, .removed = 0 };
        }
    }
    var added: usize = 0;
    for (now.items) |b| {
        if (indexOfBackdrop(s.backdrops.items, b) == null) added += 1;
    }
    var removed: usize = 0;
    var i: usize = 0;
    while (i < s.backdrops.items.len) {
        const b = s.backdrops.items[i];
        if (b.document == @intFromPtr(document)) {
            if (indexOfBackdrop(now.items, b) == null) removed += 1;
            _ = s.backdrops.swapRemove(i);
            continue;
        }
        i += 1;
    }
    s.backdrops.appendSlice(session.allocator, now.items) catch {};
    return .{ .added = added, .removed = removed };
}

fn indexOfBackdrop(list: []const Backdrop, b: Backdrop) ?usize {
    for (list, 0..) |item, i| {
        if (item.document == b.document and item.element == b.element and item.generation == b.generation) return i;
    }
    return null;
}

/// The style recalc's pseudo-element updates, for the elements the client
/// has: in tree order, each element's ::marker, ::backdrop and ::before
/// before its children and its ::after after them (Element::RecalcOwnStyle
/// and RecalcPseudoStyles' order), a new one PseudoElementCreated - its
/// parent's children pushed, then pseudoElementAdded - and a gone one
/// PseudoElementDestroyed - unbound, then pseudoElementRemoved.
fn updatePseudoElements(session: *PageSession, document: *runtime.Instance) void {
    const map = session.states.DOM.map orelse return;
    if (map.boundId(document) == 0) return;
    const Frame = struct { node: *runtime.Instance, after: bool };
    var stack: std.ArrayListUnmanaged(Frame) = .empty;
    defer stack.deinit(session.allocator);
    stack.append(session.allocator, .{ .node = document, .after = false }) catch return;
    var children: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer children.deinit(session.allocator);
    while (stack.pop()) |frame| {
        const node = frame.node;
        const is_element = (interfaces.Node.get_nodeType(node) catch 0) == 1;
        if (frame.after) {
            updatePseudo(session, node, 2);
            continue;
        }
        const id = map.boundId(node);
        if (id == 0) continue;
        if (is_element) {
            recordPseudos(session, node);
            updatePseudo(session, node, 3);
            updatePseudo(session, node, 4);
            updatePseudo(session, node, 1);
            stack.append(session.allocator, .{ .node = node, .after = true }) catch return;
        }
        if (!map.childrenRequested(id)) continue;
        // The children, pushed so the first pops first.
        children.clearRetainingCapacity();
        if (is_element) if (dom.shadow_hosts.rootForHost(node)) |root| children.append(session.allocator, root) catch return;
        var child = innerFirstChild(session, node);
        while (child) |c| : (child = innerNextSibling(session, c)) {
            if ((interfaces.Node.get_nodeType(c) catch 0) == 1 or c.implements(interfaces.ShadowRoot.State)) children.append(session.allocator, c) catch return;
        }
        var i = children.items.len;
        while (i > 0) {
            i -= 1;
            stack.append(session.allocator, .{ .node = children.items[i], .after = false }) catch return;
        }
    }
}

/// The element's pseudo-elements as its style says now: the recalc's
/// record, which its pseudo-element updates read.
fn recordPseudos(session: *PageSession, element: *runtime.Instance) void {
    const s = &session.states.DOM;
    const record: PseudoRecord = .{ .generation = runtime.SlabAllocator.generationOf(element), .bits = dom.style.engine.generatedPseudos(element) };
    s.pseudo_state_guard.beforeInsert(&s.pseudo_state);
    s.pseudo_state.put(session.allocator, @intFromPtr(element), record) catch {};
}

/// One pseudo-element of a bound element at the style recalc: made or
/// destroyed as its record (recordPseudos) says.
fn updatePseudo(session: *PageSession, element: *runtime.Instance, kind: u3) void {
    const s = &session.states.DOM;
    const map = s.map orelse return;
    const parent_id = map.boundId(element);
    if (parent_id == 0) return;
    const record = s.pseudo_state.get(@intFromPtr(element)) orelse return;
    if (record.generation != runtime.SlabAllocator.generationOf(element)) return;
    const exists = hasPseudo(record.bits, kind);
    const bound = map.pseudoId(element, kind);
    const pseudo = pseudo_kinds[kind - 1];
    if (exists and bound == 0) {
        pushChildNodes(session, parent_id, 1, false) catch return;
        const value = buildPseudoNode(session, element, pseudo, true) catch return;
        session.emit(D.pseudoElementAdded, .{ .parentId = parent_id, .pseudoElement = value });
    } else if (!exists and bound != 0) {
        _ = map.forgetPseudo(element, kind);
        // PseudoElementDestroyed: the PseudoElement is gone, its id with it.
        if (nodeIds(session)) |ids| ids.forgetPseudo(element, kind);
        session.emit(D.pseudoElementRemoved, .{ .parentId = parent_id, .pseudoElementId = bound });
    }
}

/// DidPerformSlotDistribution for the pending slots of `document`.
fn sendDistributions(session: *PageSession, document: *runtime.Instance) void {
    const s = &session.states.DOM;
    if (s.pending_slots.items.len == 0) return;
    const map = s.map orelse return;
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    var i: usize = 0;
    while (i < s.pending_slots.items.len) {
        const slot = s.pending_slots.items[i].get() orelse {
            _ = s.pending_slots.orderedRemove(i);
            continue;
        };
        if (nodeDocumentOf(slot) != document) {
            i += 1;
            continue;
        }
        _ = s.pending_slots.orderedRemove(i);
        const slot_id = map.boundId(slot);
        if (slot_id == 0) continue;
        const nodes = distributedNodesOf(session, arena_state.allocator(), slot) catch continue;
        session.emit(D.distributedNodesUpdated, .{ .insertionPointId = slot_id, .distributedNodes = nodes });
    }
}

/// BuildDistributedNodesForSlot: the slot's assigned nodes as BackendNodes,
/// whitespace-only text left out.
fn distributedNodesOf(session: *PageSession, arena: Allocator, slot: *runtime.Instance) ![]const D.BackendNode {
    var out: std.ArrayListUnmanaged(D.BackendNode) = .empty;
    const base = dom.instance_bridge.getNodeBase(slot) orelse return out.items;
    const state = dom.slot_helpers.slotState(base) orelse return out.items;
    for (state.assigned_nodes.items) |ref| {
        const assigned = ref.get() orelse continue;
        const node = assigned.registeredInstance() orelse continue;
        if (skipped(session, node)) continue;
        try out.append(arena, try backendNodeOf(session, arena, node));
    }
    return out.items;
}

/// BuildBackendNode.
fn backendNodeOf(session: *PageSession, arena: Allocator, node: *runtime.Instance) !D.BackendNode {
    const ids = nodeIds(session) orelse return error.OutOfMemory;
    var name = interfaces.Node.get_nodeName(node) catch runtime.DOMString.initEmpty();
    defer name.deinit(node.ctx.allocator);
    return .{
        .nodeType = interfaces.Node.get_nodeType(node) catch 0,
        .nodeName = try arena.dupe(u8, name.asSlice()),
        .backendNodeId = try ids.idOf(node),
    };
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
    const value = buildNode(session, arena_state.allocator(), owner, 0, false, .{ .bindings = &map.document }) catch return;
    const previous = innerPreviousSibling(session, owner);
    const previous_id = if (previous) |p| map.boundId(p) else 0;
    session.emit(D.childNodeInserted, .{ .parentNodeId = parent_id, .previousNodeId = previous_id, .node = value });
}

/// Unbind: `node`'s binding goes, with its content document's and its
/// shadow root's, and - for a node whose children the client had - each
/// inner child's, down the tree. A work list, not recursion: a client can
/// hold a whole document of any depth.
fn unbind(session: *PageSession, map: *NodeMap, node: *runtime.Instance) void {
    unbindTree(session, map, node, false);
}

/// `unbind`, for `node` leaving its tree: Blink destroys a removed element's
/// PseudoElements, so their backendNodeIds go too and a pseudo-element made
/// again on reinsertion is a new node (Chrome 157's trace: a new id).
fn unbindRemoved(session: *PageSession, map: *NodeMap, node: *runtime.Instance) void {
    unbindTree(session, map, node, true);
}

fn unbindTree(session: *PageSession, map: *NodeMap, node: *runtime.Instance, removed: bool) void {
    var stack: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer stack.deinit(session.allocator);
    var next: ?*runtime.Instance = node;
    while (next) |current| : (next = stack.pop()) {
        const forgotten = map.forget(current);
        if (forgotten.id == 0) continue;
        if ((interfaces.Node.get_nodeType(current) catch 0) == 1) {
            // "ForEachSupportedPseudo(element, unbind_pseudo)".
            for (pseudo_kinds) |pseudo| {
                if (map.forgetPseudo(current, pseudo.kind) != 0 and removed) {
                    if (nodeIds(session)) |ids| ids.forgetPseudo(current, pseudo.kind);
                }
            }
            const s = &session.states.DOM;
            if (s.pseudo_state.remove(@intFromPtr(current))) s.pseudo_state_guard.noteRemoval(&s.pseudo_state);
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
/// their children further down - in the map the node is bound in (the
/// document's, or a detached tree's: id_to_nodes_map_).
fn pushChildNodes(session: *PageSession, node_id: i64, depth: i64, pierce: bool) !void {
    const map = session.states.DOM.map orelse return;
    const node = map.nodeOf(node_id) orelse return;
    const node_type = interfaces.Node.get_nodeType(node) catch 0;
    if (node_type != 1 and node_type != 9 and node_type != 11) return;
    const bindings = map.bindingsOf(node_id) orelse return;
    if (map.childrenRequested(node_id)) {
        if (depth <= 1) return;
        var child = innerFirstChild(session, node);
        while (child) |c| : (child = innerNextSibling(session, c)) {
            const child_id = bindings.idOf(c);
            if (child_id != 0) try pushChildNodes(session, child_id, depth - 1, pierce);
        }
        return;
    }
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const children = try buildChildren(session, arena_state.allocator(), node, depth, pierce, .{ .bindings = bindings });
    session.emit(D.setChildNodes, .{ .parentId = node_id, .nodes = children });
}

/// PushNodePathToFrontend(node, nodes_map): `node`'s id in `bindings`,
/// after the client has been sent every ancestor's children down from the
/// nearest ancestor in that map; 0 when the client has no document, or the
/// node's tree does not reach the map.
fn pushNodePathIn(session: *PageSession, node: *runtime.Instance, bindings: *Bindings) !i64 {
    const map = session.states.DOM.map orelse return 0;
    // "InspectorDOMAgent might have been resetted already."
    const document = topDocument(session) orelse return 0;
    if (map.boundId(document) == 0) return 0;
    const known = bindings.idOf(node);
    if (known != 0) return known;
    var path: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer path.deinit(session.allocator);
    var current = node;
    while (true) {
        const parent = innerParent(session, current) orelse return 0;
        try path.append(session.allocator, parent);
        if (bindings.contains(parent)) break;
        current = parent;
    }
    var i = path.items.len;
    while (i > 0) {
        i -= 1;
        const id = bindings.idOf(path.items[i]);
        if (id != 0) try pushChildNodes(session, id, 1, false);
    }
    return bindings.idOf(node);
}

/// PushNodePathToFrontend(node): its path in the document's map, or - for a
/// node outside the document ("Node being pushed is detached -> push subtree
/// root") - its tree's root, built at depth 0 into a map of its own that
/// holds the root, sent as setChildNodes with parent 0, then its path in
/// that map. 0 with no agent document (an agent not enabled).
fn pushNodePath(session: *PageSession, node: *runtime.Instance) !i64 {
    if (!session.states.DOM.enabled) return 0;
    const map = try mapOf(session);
    const id = try pushNodePathIn(session, node, &map.document);
    if (id != 0) return id;
    var root = node;
    while (innerParent(session, root)) |parent| root = parent;
    const dangling = try map.newDangling(root);
    var arena_state = std.heap.ArenaAllocator.init(session.allocator);
    defer arena_state.deinit();
    const nodes = try arena_state.allocator().alloc(D.Node, 1);
    nodes[0] = try buildNode(session, arena_state.allocator(), root, 0, false, .{ .bindings = dangling });
    session.emit(D.setChildNodes, .{ .parentId = 0, .nodes = nodes });
    return pushNodePathIn(session, node, dangling);
}

/// Where BuildObjectForNode puts what it builds: the map it binds into
/// (none: the node's id is the one the client has, if any, and nothing is
/// bound) and, for getFlattenedDocument, the flat list that takes every
/// node built under the root (flatten_result).
const Build = struct {
    bindings: ?*Bindings = null,
    flatten: ?*std.ArrayListUnmanaged(D.Node) = null,
    /// The node was just inserted: Blink's style recalc has not made its
    /// pseudo-elements yet, so it is built with none (the next rendering
    /// update adds them: pseudoElementAdded). Not passed to what is built
    /// under it.
    no_pseudos: bool = false,
    /// The same for its assigned slot: Blink reads AssignedSlotWithoutRecalc,
    /// and a node just inserted under a shadow host has none until the
    /// assignment's recalc (Chrome 157's trace: no assignedSlot on the
    /// childNodeInserted; distributedNodesUpdated follows at the rendering
    /// update). Not passed to what is built under it.
    no_assigned_slot: bool = false,
};

/// The pseudo-elements CDP's DOM.Node lists, in ForEachSupportedPseudo's
/// order (inspector_dom_agent.cc): each with its key kind (NodeIds.
/// pseudoKey), its node name (PseudoElementTagName: "::before") and type.
const PseudoKind = struct {
    kind: u3,
    name: []const u8,
    pseudo_type: D.PseudoType,
};
const pseudo_kinds = [_]PseudoKind{
    .{ .kind = 1, .name = "::before", .pseudo_type = .before },
    .{ .kind = 2, .name = "::after", .pseudo_type = .after },
    .{ .kind = 3, .name = "::marker", .pseudo_type = .marker },
    .{ .kind = 4, .name = "::backdrop", .pseudo_type = .backdrop },
};

fn hasPseudo(bits: dom.style.engine.GeneratedPseudos, kind: u3) bool {
    return switch (kind) {
        1 => bits.before,
        2 => bits.after,
        3 => bits.marker,
        4 => bits.backdrop,
        else => false,
    };
}

/// The pseudo-elements `element` has as far as the agent knows - as of the
/// style recalc that last looked at it (the rendering update's walk), or,
/// for an element no recalc has looked at, as its style says now - and
/// remembered so the next rendering update reports changes from it.
fn pseudosOf(session: *PageSession, element: *runtime.Instance, fresh: bool) dom.style.engine.GeneratedPseudos {
    const s = &session.states.DOM;
    const generation = runtime.SlabAllocator.generationOf(element);
    if (s.pseudo_state.get(@intFromPtr(element))) |record| {
        if (record.generation == generation) return record.bits;
    }
    // A session whose agent is not enabled (describeNode from a runner)
    // is told of none: Crane has no PseudoElement nodes to read, and a
    // style resolution per described node is a cost no runner asked for.
    // Blink reads the ones its last style recalc made.
    if (!s.enabled) return .{};
    if (s.in_probe and !fresh) return .{};
    const bits: dom.style.engine.GeneratedPseudos = if (fresh) .{} else dom.style.engine.generatedPseudos(element);
    s.pseudo_state.put(session.allocator, @intFromPtr(element), .{ .generation = generation, .bits = bits }) catch {};
    return bits;
}

/// BuildObjectForNode for a pseudo-element (a PseudoElement node in Blink):
/// an element named "::before" and the like, with no attributes and no
/// children, bound in the document's map when building there.
fn buildPseudoNode(session: *PageSession, element: *runtime.Instance, pseudo: PseudoKind, bind: bool) Allocator.Error!D.Node {
    const ids = nodeIds(session) orelse return error.OutOfMemory;
    const map = session.states.DOM.map;
    const id: i64 = if (map) |m| (if (bind) try m.bindPseudo(element, pseudo.kind) else m.pseudoId(element, pseudo.kind)) else 0;
    if (bind) try map.?.setChildCount(id, 0);
    return .{
        .nodeId = id,
        .backendNodeId = try ids.idOfPseudo(element, pseudo.kind),
        .nodeType = 1,
        .nodeName = pseudo.name,
        .localName = pseudo.name,
        .nodeValue = "",
        .attributes = &.{},
        .pseudoType = pseudo.pseudo_type,
        .childNodeCount = 0,
    };
}

/// Blink's BuildObjectForNode. With `build.bindings` the node and what is
/// built under it are bound (pushed to the client); without one a node's id
/// is the one the client has, if any.
fn buildNode(session: *PageSession, arena: Allocator, node: *runtime.Instance, depth_in: i64, pierce: bool, build: Build) Allocator.Error!D.Node {
    var depth = depth_in;
    const ids = nodeIds(session) orelse return error.OutOfMemory;
    const map = session.states.DOM.map;
    const node_id: i64 = if (build.bindings) |b| try map.?.bindIn(b, node) else if (map) |m| m.boundId(node) else 0;
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
                    content.* = try buildNode(session, arena, document, if (pierce) depth else 0, pierce, build);
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
                roots[0] = try buildNode(session, arena, root, if (pierce) depth else 0, pierce, build);
                described.shadowRoots = roots;
                force_push_children = true;
            }
            // A link element's children go with it (Blink: imports once).
            if (isHtmlElementNamed(node, "link")) force_push_children = true;
            // A template's contents.
            if (isHtmlElementNamed(node, "template")) {
                if (interfaces.HTMLTemplateElement.get_content(node) catch null) |content| {
                    const template_content = try arena.create(D.Node);
                    template_content.* = try buildNode(session, arena, content, 0, pierce, build);
                    described.templateContent = template_content;
                    force_push_children = true;
                }
            }
            // A slotted element names its slot (AssignedSlotWithoutRecalc).
            if (!build.no_assigned_slot) if (assignedSlotOf(node)) |slot| {
                described.assignedSlot = try backendNodeOf(session, arena, slot);
            };
            // Its pseudo-elements (BuildArrayForPseudoElements), which go
            // with it.
            {
                const bits = pseudosOf(session, node, build.no_pseudos);
                var pseudos: std.ArrayListUnmanaged(D.Node) = .empty;
                const bind = if (build.bindings) |b| b == &map.?.document else false;
                for (pseudo_kinds) |pseudo| {
                    if (!hasPseudo(bits, pseudo.kind)) continue;
                    try pseudos.append(arena, try buildPseudoNode(session, node, pseudo, bind));
                }
                if (pseudos.items.len != 0) {
                    described.pseudoElements = pseudos.items;
                    force_push_children = true;
                }
            }
            // A slot in a shadow tree: its distributed nodes, and its
            // children go with it.
            if (isHtmlElementNamed(node, "slot") and inShadowTree(node)) {
                described.distributedNodes = try distributedNodesOf(session, arena, node);
                force_push_children = true;
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
            if (dom.style.adopted.arrayExists(node)) described.adoptedStyleSheets = try adoptedSheetIds(session, arena, node);
            const url = interfaces.Document.get_URL(node) catch "";
            defer if (url.len > 0) node.ctx.allocator.free(url);
            described.documentURL = try arena.dupe(u8, url);
            const base = interfaces.Node.get_baseURI(node) catch "";
            defer if (base.len > 0) node.ctx.allocator.free(base);
            described.baseURL = try arena.dupe(u8, base);
            described.xmlVersion = "";
            described.compatibilityMode = compatibilityModeOf(node);
            // No frameId on a document: Blink's BuildObjectForNode names the
            // frame on a frame owner and on the document element only
            // (Chrome 157's trace).
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
        // DOCUMENT_FRAGMENT_NODE: a shadow root's type and adopted sheets.
        11 => {
            if (node.implements(interfaces.ShadowRoot.State)) {
                if (dom.style.adopted.arrayExists(node)) described.adoptedStyleSheets = try adoptedSheetIds(session, arena, node);
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
        if (build.bindings) |b| if (b == &map.?.document) try map.?.setChildCount(node_id, count);
        if (build.bindings != null and force_push_children and depth == 0) depth = 1;
        var under = build;
        under.no_pseudos = false;
        under.no_assigned_slot = false;
        const children = try buildChildren(session, arena, node, depth, pierce, under);
        // "Push children along with shadow in any case."
        if (children.len != 0 or depth != 0) described.children = children;
    }
    return described;
}

/// BuildArrayForContainerChildren: `container`'s children to `depth`, each
/// with its parentId - into the flat list instead, for getFlattenedDocument.
/// At depth 0 with a map, an only text child is pushed anyway, as if the
/// container's children had been asked for.
fn buildChildren(session: *PageSession, arena: Allocator, container: *runtime.Instance, depth: i64, pierce: bool, build: Build) Allocator.Error![]const D.Node {
    var children: std.ArrayListUnmanaged(D.Node) = .empty;
    const map = session.states.DOM.map;
    if (depth == 0) {
        const bindings = build.bindings orelse return children.items;
        const first = interfaces.Node.get_firstChild(container) catch null;
        if (first) |only| {
            if ((interfaces.Node.get_nodeType(only) catch 0) == 3 and (interfaces.Node.get_nextSibling(only) catch null) == null) {
                var child_node = try buildNode(session, arena, only, 0, pierce, build);
                const parent_id = try map.?.bindIn(bindings, container);
                child_node.parentId = parent_id;
                if (build.flatten) |flat| try flat.append(arena, child_node) else try children.append(arena, child_node);
                try map.?.markChildrenRequested(parent_id);
            }
        }
        return children.items;
    }
    // Bind(container, nodes_map): 0 with no map.
    const parent_id: i64 = if (build.bindings) |b| try map.?.bindIn(b, container) else 0;
    if (build.bindings != null) try map.?.markChildrenRequested(parent_id);
    var child = innerFirstChild(session, container);
    while (child) |c| : (child = innerNextSibling(session, c)) {
        var child_node = try buildNode(session, arena, c, depth - 1, pierce, build);
        child_node.parentId = parent_id;
        if (build.flatten) |flat| try flat.append(arena, child_node) else try children.append(arena, child_node);
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

/// The slot `node` is assigned to, if any.
fn assignedSlotOf(node: *runtime.Instance) ?*runtime.Instance {
    const base = dom.instance_bridge.getNodeBase(node) orelse return null;
    const slottable = dom.slot_helpers.slottable(base) orelse return null;
    const slot = slottable.state.assignedSlot() orelse return null;
    return slot.registeredInstance();
}

/// Whether `node`'s root is a shadow root (Node::IsInShadowTree).
fn inShadowTree(node: *runtime.Instance) bool {
    var current = node;
    while (interfaces.Node.get_parentNode(current) catch null) |parent| current = parent;
    return current.implements(interfaces.ShadowRoot.State);
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
