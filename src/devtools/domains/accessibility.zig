//! The Accessibility domain (lane a11y1; design tmp/plans/a11y1-design.md):
//! the accessibility tree of a frame's document as Chrome 157 answers it -
//! Blink's InspectorAccessibilityAgent
//! (third_party/blink/renderer/modules/accessibility/
//! inspector_accessibility_agent.cc) and its node builder
//! (inspector_type_builder_helper.cc), Chromium tag 157.0.8103.78, BSD-3:
//! reproduced, each function citing the one it follows.
//!
//! The tree is dom.accessibility_tree's, built for the command and dropped
//! with the command's arena; nothing here holds a node. An AX node with a DOM
//! node has that node's backendNodeId as its id (Blink's AXID is the
//! DOMNodeId); one with none has a generated negative id (ax_ids.zig).
//!
//! getFullAXTree, getPartialAXTree and queryAXTree need no enable (Blink
//! attaches its cache for them); getRootAXNode, getChildAXNodes and
//! getAXNodeAndAncestors answer "Accessibility has not been enabled."
//! without it. The events (loadComplete, nodesUpdated) are batch 3's.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const dom = @import("dom");
const html = @import("html");
const interfaces = @import("interfaces");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const Reply = @import("../dispatch.zig").Reply;
const frames = @import("../frames.zig");
const NodeIds = @import("../node_ids.zig").NodeIds;
const AxIds = @import("../ax_ids.zig").AxIds;
const dom_domain = @import("dom.zig");

const A = protocol.Accessibility;
const ax = dom.accessibility_tree;
const Tree = ax.Tree;
const Index = ax.Index;

/// Per session (Blink: one agent per session).
pub const State = struct {
    enabled: bool = false,
    /// The AX node ids the client asked for (Blink nodes_requested_): what
    /// nodesUpdated reports on. Ids only, never nodes.
    requested: std.AutoHashMapUnmanaged(i64, void) = .empty,
};

pub fn sessionEnded(session: *PageSession) void {
    session.states.Accessibility.requested.deinit(session.allocator);
    session.states.Accessibility = .{};
}

/// InspectorAccessibilityAgent::enable.
pub fn enable(session: *PageSession, params: A.enable.Params) !A.enable.Result {
    _ = params;
    session.states.Accessibility.enabled = true;
    return .{};
}

/// InspectorAccessibilityAgent::disable: forgets what was requested.
pub fn disable(session: *PageSession, params: A.disable.Params) !A.disable.Result {
    _ = params;
    const s = &session.states.Accessibility;
    if (!s.enabled) return .{};
    s.enabled = false;
    s.requested.clearRetainingCapacity();
    return .{};
}

// ============================================================================
// The commands
// ============================================================================

/// InspectorAccessibilityAgent::getFullAXTree: the frame's tree, root first,
/// to `depth` (WalkAXNodesToDepth).
pub fn getFullAXTree(session: *PageSession, params: A.getFullAXTree.Params) !A.getFullAXTree.Result {
    const bc = frames.frameNamed(session, params.frameId) orelse return session.failWithCode(.invalid_params, "Frame with the given frameId is not found.");
    const document = frames.documentOf(bc) orelse return session.failWithCode(.internal_error, "Internal error");
    var s = try Serializer.init(session, document);
    var nodes: std.ArrayListUnmanaged(A.AXNode) = .empty;
    try s.walkToDepth(&nodes, params.depth orelse -1);
    return .{ .nodes = nodes.items };
}

/// InspectorAccessibilityAgent::getRootAXNode.
pub fn getRootAXNode(session: *PageSession, params: A.getRootAXNode.Params) !A.getRootAXNode.Result {
    const bc = frames.frameNamed(session, params.frameId) orelse return session.failWithCode(.invalid_params, "Frame with the given frameId is not found.");
    if (!session.states.Accessibility.enabled) return session.fail("Accessibility has not been enabled.");
    const document = frames.documentOf(bc) orelse return session.failWithCode(.internal_error, "Internal error");
    var s = try Serializer.init(session, document);
    const root = try s.build(s.tree.root(), false);
    try request(session, try s.axId(s.tree.root()));
    return .{ .node = root };
}

/// InspectorAccessibilityAgent::getAXNodeAndAncestors: the node's object
/// and each included ancestor, up to the root.
pub fn getAXNodeAndAncestors(session: *PageSession, params: A.getAXNodeAndAncestors.Params) !A.getAXNodeAndAncestors.Result {
    if (!session.states.Accessibility.enabled) return session.fail("Accessibility has not been enabled.");
    const node = try dom_domain.nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
    const document = documentOf(node) orelse return session.fail("Frame is detached.");
    var s = try Serializer.init(session, document);
    var nodes: std.ArrayListUnmanaged(A.AXNode) = .empty;
    var at = s.tree.indexOf(node) orelse {
        try nodes.append(s.arena, try s.noAXNode(node));
        return .{ .nodes = nodes.items };
    };
    while (true) {
        try request(session, try s.axId(at));
        try nodes.append(s.arena, try s.build(at, false));
        at = s.tree.node(at).parent orelse break;
    }
    return .{ .nodes = nodes.items };
}

/// InspectorAccessibilityAgent::getChildAXNodes: the children of the
/// object named `id` (AddChildren, following ignored ones).
pub fn getChildAXNodes(session: *PageSession, params: A.getChildAXNodes.Params) !A.getChildAXNodes.Result {
    if (!session.states.Accessibility.enabled) return session.fail("Accessibility has not been enabled.");
    const bc = frames.frameNamed(session, params.frameId) orelse return session.failWithCode(.invalid_params, "Frame with the given frameId is not found.");
    const document = frames.documentOf(bc) orelse return session.failWithCode(.internal_error, "Internal error");
    var s = try Serializer.init(session, document);
    // StringToIntLoose: a non-number is 0, which names no object.
    const id = std.fmt.parseInt(i64, params.id, 10) catch 0;
    const index = (try s.indexOfId(id)) orelse return session.failWithCode(.invalid_params, "Invalid ID");
    var nodes: std.ArrayListUnmanaged(A.AXNode) = .empty;
    try s.addChildren(index, &nodes);
    for (nodes.items) |n| try request(session, std.fmt.parseInt(i64, n.nodeId, 10) catch 0);
    return .{ .nodes = nodes.items };
}

/// InspectorAccessibilityAgent::getPartialAXTree: the node's object (or a
/// stand-in when it has none), its children, and its ancestors.
pub fn getPartialAXTree(session: *PageSession, params: A.getPartialAXTree.Params) !A.getPartialAXTree.Result {
    const node = try dom_domain.nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
    const document = documentOf(node) orelse return session.fail("Frame is detached.");
    var s = try Serializer.init(session, document);
    var nodes: std.ArrayListUnmanaged(A.AXNode) = .empty;
    const inspected = s.tree.indexOf(node);
    if (inspected) |index| {
        try nodes.append(s.arena, try s.build(index, false));
    } else {
        try nodes.append(s.arena, try s.noAXNode(node));
    }
    if (!(params.fetchRelatives orelse true)) return .{ .nodes = nodes.items };
    if (inspected) |index| if (!s.tree.node(index).ignored) try s.addChildren(index, &nodes);
    // The first ancestor in the tree: the object's parent, or for a node
    // with none, the nearest flat-tree ancestor that has one (a shadow
    // root's host).
    const parent: ?Index = if (inspected) |index| s.tree.node(index).parent else blk: {
        var at = flatParent(node);
        while (at) |p| : (at = flatParent(p)) if (s.tree.indexOf(p)) |found| break :blk found;
        break :blk null;
    };
    const first = parent orelse return .{ .nodes = nodes.items };
    // AddAncestors: an ignored (or missing) inspected node is missing from
    // its parent's childIds, so it is put first there.
    var first_node = try s.build(first, false);
    const ignored = if (inspected) |index| s.tree.node(index).ignored else true;
    if (ignored) {
        const own: []const u8 = if (inspected) |index| try s.idString(index) else "0";
        var child_ids: std.ArrayListUnmanaged([]const u8) = .empty;
        try child_ids.append(s.arena, own);
        if (first_node.childIds) |existing| try child_ids.appendSlice(s.arena, existing);
        first_node.childIds = child_ids.items;
    }
    try nodes.append(s.arena, first_node);
    var at = s.tree.node(first).parent;
    while (at) |ancestor| : (at = s.tree.node(ancestor).parent) try nodes.append(s.arena, try s.build(ancestor, false));
    return .{ .nodes = nodes.items };
}

/// InspectorAccessibilityAgent::queryAXTree (CompleteQuery): every object
/// in the tree under the node's (a shadow root: its host's), pre-order,
/// whose name and role match - ignored ones too, their name and role sent.
pub fn queryAXTree(session: *PageSession, params: A.queryAXTree.Params) !A.queryAXTree.Result {
    var node = try dom_domain.nodeNamed(session, params.nodeId, params.backendNodeId, params.objectId);
    if (node.implements(interfaces.ShadowRoot.State)) {
        node = (interfaces.ShadowRoot.get_host(node) catch null) orelse return session.failWithCode(.invalid_params, "Root DOM node could not be found");
    }
    const document = documentOf(node) orelse return session.failWithCode(.invalid_params, "Root DOM node could not be found");
    var s = try Serializer.init(session, document);
    var nodes: std.ArrayListUnmanaged(A.AXNode) = .empty;
    const start = s.tree.indexOf(node) orelse return .{ .nodes = nodes.items };
    var stack: std.ArrayListUnmanaged(Index) = .empty;
    try stack.append(s.arena, start);
    while (stack.pop()) |index| {
        const object = s.tree.node(index);
        // Not in the tree: neither it nor (it has none) its children.
        if (!object.included) continue;
        // Inline text boxes are never answered (Chrome 157: a query by a
        // text's name finds the StaticText, not its boxes).
        if (object.role == .InlineTextBox) continue;
        var i = object.children.items.len;
        while (i > 0) {
            i -= 1;
            try stack.append(s.arena, object.children.items[i]);
        }
        if (params.accessibleName) |wanted| {
            const name = try ax.nameOf(s.tree, index);
            if (!std.mem.eql(u8, wanted, name)) continue;
        }
        if (params.role) |wanted| {
            // AXObject::RoleName of the serialized role (an ignored object's
            // own role: AXNodeData's role is its real one).
            if (!std.mem.eql(u8, wanted, object.role.cdpName().name)) continue;
        }
        try nodes.append(s.arena, try s.build(index, true));
    }
    return .{ .nodes = nodes.items };
}

fn request(session: *PageSession, id: i64) !void {
    try session.states.Accessibility.requested.put(session.allocator, id, {});
}

/// The node's document, when it has a browsing context.
fn documentOf(node: *runtime.Instance) ?*runtime.Instance {
    if (node.implements(interfaces.Document.State)) return node;
    return interfaces.Node.get_ownerDocument(node) catch null;
}

/// The flat-tree parent, a shadow root's host for a shadow root.
fn flatParent(node: *runtime.Instance) ?*runtime.Instance {
    if (node.implements(interfaces.ShadowRoot.State)) return interfaces.ShadowRoot.get_host(node) catch null;
    return dom.accessibility.parent(node);
}

// ============================================================================
// The host's answers (dom.accessibility_tree.Options)
// ============================================================================

fn isFocusable(node: *runtime.Instance) bool {
    return html.focus.isFocusableArea(node);
}

fn isInert(node: *runtime.Instance) bool {
    return html.focus.isInertNode(node);
}

/// HTML 4.15 "actually disabled", for the elements that can be.
fn isDisabled(element: *runtime.Instance) bool {
    const fa = html.form_associated;
    if (fa.isButton(element) or fa.isInput(element) or fa.isSelect(element) or fa.isTextArea(element) or fa.isFormAssociatedCustom(element)) return fa.isDisabled(element);
    const name = dom.accessibility.localName(element);
    if (!dom.accessibility.isHtml(element)) return false;
    if (std.mem.eql(u8, name, "fieldset")) return fa.isDisabled(element);
    if (std.mem.eql(u8, name, "optgroup")) return dom.accessibility.attribute(element, "disabled") != null;
    if (std.mem.eql(u8, name, "option")) return html.forms.options.isDisabled(element);
    return false;
}

const options: ax.Options = .{ .is_focusable = &isFocusable, .is_inert = &isInert, .is_disabled = &isDisabled };

// ============================================================================
// Building AXNodes (inspector_type_builder_helper.cc)
// ============================================================================

const Serializer = struct {
    session: *PageSession,
    arena: Allocator,
    tree: *Tree,
    ids: *NodeIds,
    ax_ids: *AxIds,
    document: *runtime.Instance,

    fn init(session: *PageSession, document: *runtime.Instance) !Serializer {
        const arena = session.arena.?;
        const browser = session.browser orelse return error.NoBrowser;
        const tree = try arena.create(Tree);
        tree.* = try Tree.build(arena, document, options);
        return .{
            .session = session,
            .arena = arena,
            .tree = tree,
            .ids = try browser.scope.of(NodeIds),
            .ax_ids = try browser.scope.of(AxIds),
            .document = document,
        };
    }

    /// The object's AXID: its node's backendNodeId, or a generated one.
    fn axId(self: *Serializer, index: Index) Allocator.Error!i64 {
        const object = self.tree.node(index);
        return switch (object.source) {
            .node => |n| self.ids.idOf(n),
            .pseudo => |p| self.ids.idOfPseudo(p.element, @backingInt(p.kind)),
            .nodeless => |ordinal| self.ax_ids.idOf(.{ .parent = try self.axId(object.parent.?), .ordinal = ordinal }),
        };
    }

    fn idString(self: *Serializer, index: Index) Allocator.Error![]const u8 {
        return std.fmt.allocPrint(self.arena, "{d}", .{try self.axId(index)});
    }

    /// The object an AXID names in this tree, if any.
    fn indexOfId(self: *Serializer, id: i64) !?Index {
        if (id == 0) return null;
        if (id > 0) {
            if (self.ids.nodeOf(id)) |n| return self.tree.indexOf(n);
        }
        // A pseudo-element's or a generated id: search the tree.
        for (0..self.tree.nodes.items.len) |i| {
            const index: Index = @intCast(i);
            if (try self.axId(index) == id) return index;
        }
        return null;
    }

    /// WalkAXNodesToDepth: the root, then breadth first over unignored
    /// objects, each adding its children (AddChildren, following ignored and
    /// nodeless ones).
    fn walkToDepth(self: *Serializer, out: *std.ArrayListUnmanaged(A.AXNode), max_depth: i64) !void {
        const root = self.tree.root();
        try out.append(self.arena, try self.build(root, false));
        const Item = struct { index: Index, depth: i64 };
        var queue: std.ArrayListUnmanaged(Item) = .empty;
        try queue.append(self.arena, .{ .index = root, .depth = 1 });
        var head: usize = 0;
        while (head < queue.items.len) : (head += 1) {
            const item = queue.items[head];
            try self.addChildren(item.index, out);
            var unignored: std.ArrayListUnmanaged(Index) = .empty;
            try self.unignoredChildren(item.index, &unignored);
            for (unignored.items) |child| {
                if (max_depth == -1 or item.depth < max_depth) try queue.append(self.arena, .{ .index = child, .depth = item.depth + 1 });
            }
        }
    }

    /// AddChildren(follow_ignored = true).
    fn addChildren(self: *Serializer, index: Index, out: *std.ArrayListUnmanaged(A.AXNode)) !void {
        var stack: std.ArrayListUnmanaged(Index) = .empty;
        try pushReversed(self.arena, &stack, self.tree.node(index).children.items);
        while (stack.pop()) |child| {
            const object = self.tree.node(child);
            // Blink follows ignored objects and those with no DOM node. A
            // select's pop-up has one in Chrome (a user-agent shadow
            // element) and none in Crane: it is followed as Chrome does.
            const nodeless = object.source == .nodeless and object.role != .MenuListPopup;
            if (object.ignored or nodeless) try pushReversed(self.arena, &stack, object.children.items);
            try out.append(self.arena, try self.build(child, false));
        }
    }

    fn pushReversed(arena: Allocator, stack: *std.ArrayListUnmanaged(Index), items: []const Index) !void {
        var i = items.len;
        while (i > 0) {
            i -= 1;
            try stack.append(arena, items[i]);
        }
    }

    /// UnignoredChildrenSlow: an ignored child's unignored descendants take
    /// its place.
    fn unignoredChildren(self: *Serializer, index: Index, out: *std.ArrayListUnmanaged(Index)) !void {
        for (self.tree.node(index).children.items) |child| {
            if (self.tree.node(child).ignored) {
                try self.unignoredChildren(child, out);
            } else {
                try out.append(self.arena, child);
            }
        }
    }

    /// BuildProtocolAXNodeForAXObject.
    fn build(self: *Serializer, index: Index, force_name_and_role: bool) !A.AXNode {
        const object = self.tree.node(index);
        var node: A.AXNode = .{ .nodeId = try self.idString(index), .ignored = object.ignored };
        const described = try ax.describe(self.tree, index, force_name_and_role);
        if (object.ignored) {
            const role: ax.Role = if (force_name_and_role) object.role else .None;
            node.role = roleValue(role);
            node.chromeRole = chromeRole(role);
            if (force_name_and_role) node.name = .{ .type = .computedString, .value = .{ .string = described.name orelse "" } };
            var reasons: std.ArrayListUnmanaged(A.AXProperty) = .empty;
            for (object.reasons) |reason| try reasons.append(self.arena, try self.reasonProperty(reason));
            node.ignoredReasons = reasons.items;
        } else {
            node.role = roleValue(object.role);
            node.chromeRole = chromeRole(object.role);
            var properties: std.ArrayListUnmanaged(A.AXProperty) = .empty;
            for (described.properties) |p| try properties.append(self.arena, try self.property(p));
            node.properties = properties.items;
            node.name = .{ .type = .computedString, .value = .{ .string = described.name orelse "" } };
            if (described.description.len > 0) node.description = .{ .type = .computedString, .value = .{ .string = described.description } };
            if (described.value) |v| node.value = try self.value(v);
        }
        var child_ids: std.ArrayListUnmanaged([]const u8) = .empty;
        for (object.children.items) |child| try child_ids.append(self.arena, try self.idString(child));
        node.childIds = child_ids.items;
        switch (object.source) {
            .node => |n| node.backendDOMNodeId = try self.ids.idOf(n),
            .pseudo => |p| node.backendDOMNodeId = try self.ids.idOfPseudo(p.element, @backingInt(p.kind)),
            .nodeless => {},
        }
        if (object.parent) |parent| {
            node.parentId = try self.idString(parent);
        } else {
            node.frameId = try self.frameIdOf(self.document);
        }
        return node;
    }

    /// BuildProtocolAXNodeForDOMNodeWithNoAXNode.
    fn noAXNode(self: *Serializer, node: *runtime.Instance) !A.AXNode {
        var reasons: std.ArrayListUnmanaged(A.AXProperty) = .empty;
        try reasons.append(self.arena, .{ .name = .notRendered, .value = .{ .type = .boolean, .value = .{ .bool = true } } });
        return .{
            .nodeId = "0",
            .ignored = true,
            .role = roleValue(.None),
            .chromeRole = chromeRole(.None),
            .ignoredReasons = reasons.items,
            .backendDOMNodeId = try self.ids.idOf(node),
        };
    }

    fn frameIdOf(self: *Serializer, document: *runtime.Instance) ![]const u8 {
        const top = frames.navigable(self.session, self.session.tab) orelse return "";
        const bc = findByDocument(top, document) orelse return "";
        return self.arena.dupe(u8, self.session.frameId(bc.id).slice());
    }

    /// CreateProperty(IgnoredReason).
    fn reasonProperty(self: *Serializer, reason: ax.IgnoredReason) !A.AXProperty {
        const name = std.meta.stringToEnum(A.AXPropertyName, @tagName(reason.reason)) orelse .notRendered;
        if (reason.related) |related| {
            return .{ .name = name, .value = .{ .type = .idref, .relatedNodes = try self.relatedNodes(&.{.{ .node = related }}) } };
        }
        return .{ .name = name, .value = .{ .type = .boolean, .value = .{ .bool = true } } };
    }

    fn property(self: *Serializer, p: ax.Property) !A.AXProperty {
        const name = std.meta.stringToEnum(A.AXPropertyName, p.name) orelse return error.UnknownProperty;
        return .{ .name = name, .value = try self.value(p.value) };
    }

    fn value(self: *Serializer, v: ax.Value) !A.AXValue {
        return switch (v) {
            .boolean => |b| .{ .type = .boolean, .value = .{ .bool = b } },
            .boolean_or_undefined => |b| .{ .type = .booleanOrUndefined, .value = .{ .bool = b } },
            .tristate => |t| .{ .type = .tristate, .value = .{ .string = t } },
            .token => |t| .{ .type = .token, .value = .{ .string = t } },
            .token_list => |t| .{ .type = .tokenList, .value = .{ .string = t } },
            .string => |t| .{ .type = .string, .value = .{ .string = t } },
            .integer => |n| .{ .type = .integer, .value = .{ .integer = n } },
            .number => |n| .{ .type = .number, .value = numberJson(n) },
            .boolean_one => .{ .type = .boolean, .value = .{ .integer = 1 } },
            .idref => |r| .{ .type = .idref, .relatedNodes = try self.relatedNodes(&.{r}) },
            .idref_list => |l| .{
                .type = .idrefList,
                .value = if (l.attribute_value) |text| .{ .string = text } else null,
                .relatedNodes = try self.relatedNodes(l.related),
            },
            .node_list => |l| .{ .type = .nodeList, .relatedNodes = try self.relatedNodes(l) },
        };
    }

    /// RelatedNodeForAXObject: the backendDOMNodeId, the element's id as
    /// `idref`, and the text when given.
    fn relatedNodes(self: *Serializer, related: []const ax.Related) ![]const A.AXRelatedNode {
        var out: std.ArrayListUnmanaged(A.AXRelatedNode) = .empty;
        for (related) |r| {
            var node: A.AXRelatedNode = .{ .backendDOMNodeId = try self.ids.idOf(r.node) };
            if (dom.accessibility.attribute(r.node, "id")) |id| if (id.len > 0) {
                node.idref = id;
            };
            if (r.text) |text| node.text = text;
            try out.append(self.arena, node);
        }
        return out.items;
    }
};

/// CreateRoleNameValue: an ARIA role ("role") or an internal one
/// ("internalRole").
fn roleValue(role: ax.Role) A.AXValue {
    const name = role.cdpName();
    return .{ .type = if (name.internal) .internalRole else .role, .value = .{ .string = name.name } };
}

/// CreateInternalRoleValue: the role's ax_enums.mojom integer.
fn chromeRole(role: ax.Role) A.AXValue {
    return .{ .type = .internalRole, .value = .{ .integer = @backingInt(role) } };
}

/// A CDP number: an integer when the value is one (Chrome's JSON writer
/// prints 40, not 40.0).
fn numberJson(n: f64) std.json.Value {
    if (@floor(n) == n and @abs(n) < 1e15) return .{ .integer = @intFromFloat(n) };
    return .{ .float = n };
}

fn findByDocument(bc: *frames.BrowsingContext, document: *runtime.Instance) ?*frames.BrowsingContext {
    if (bc.getActiveDocument()) |active| if (active == @as(*anyopaque, @ptrCast(document))) return bc;
    for (bc.children.items) |child| {
        if (child.is_closed) continue;
        if (findByDocument(child, document)) |found| return found;
    }
    return null;
}

test "roles serialize as Chrome's: ARIA names as role, internal ones as internalRole" {
    const button = roleValue(.ToggleButton);
    try std.testing.expectEqual(A.AXValueType.role, button.type);
    try std.testing.expectEqualStrings("button", button.value.?.string);
    const root = roleValue(.RootWebArea);
    try std.testing.expectEqual(A.AXValueType.internalRole, root.type);
    try std.testing.expectEqualStrings("RootWebArea", root.value.?.string);
    try std.testing.expectEqual(@as(i64, 144), chromeRole(.RootWebArea).value.?.integer);
}

test "numbers serialize as integers when they are whole" {
    try std.testing.expectEqual(@as(i64, 40), numberJson(40).integer);
    try std.testing.expectEqual(@as(f64, 0.5), numberJson(0.5).float);
}
