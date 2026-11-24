//! The accessibility tree of one document, as Chrome's renderer builds it
//! (Blink's AXObjectCacheImpl and AXNodeObject; lane a11y1, design
//! tmp/plans/a11y1-design.md 2): what the Chrome DevTools Protocol's
//! Accessibility domain serializes (src/devtools/domains/accessibility.zig).
//!
//! Built on demand from the flat tree and computed style, inside one command,
//! and dropped with its arena: nothing here survives the task that built it,
//! so it holds nodes by plain pointer only for that extent (src/AGENTS.md,
//! "DOM lifetime"). With no DevTools session asking, none is ever built.
//!
//! Blink's rules are reproduced, not copied (Chromium tag 157.0.8103.78,
//! BSD-3; each function cites the one it follows):
//! - which nodes get an object (AXObjectCacheImpl DetermineAXObjectType,
//!   IsLayoutTextRelevantForAccessibility, CanIgnoreSpace,
//!   IsRelevantPseudoElement, IsSubtreePrunedForAccessibility);
//! - an object's role (AXNodeObject::NativeRoleIgnoringAria,
//!   AXObject::DetermineAriaRole, AXObject::ComputeFinalRoleForSerialization);
//! - whether it is ignored, and why (AXObject::ShouldIgnoreForHiddenOrInert,
//!   AXNodeObject::ComputeIsIgnored and ShouldIncludeBasedOnSemantics), and
//!   whether an ignored one stays in the tree
//!   (AXObject::ComputeIsIgnoredButIncludedInTree);
//! - its children, in order (AXNodeObject::AddChildrenImpl, AddNodeChildren,
//!   AddOwnedChildren, InsertChild's flattening of objects not in the tree).
//!
//! Crane has no layout. "Has a layout object" is answered from the cascade:
//! an element has a box when it and its flat-tree ancestors are rendered and
//! its display is not contents (style.engine.isBeingRendered); a Text has one
//! when its parent renders children and Blink's layout tree builder would make
//! one (the white-space rules of Text::TextLayoutObjectIsNeeded). None of it
//! is geometry. Where a rule needs geometry (a scrollable container, a 1x1
//! canvas) Crane answers as for content that is not, and says so there.
//!
//! The accessible name stays dom/accessibility.zig's AccName implementation,
//! the one WebDriver's computed label reads (`a11y.Names`).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const address_map = @import("infra").address_map;
const a11y = @import("accessibility.zig");
const roles = @import("accessibility_roles.zig");
const data = @import("element_data.zig");
const bridge = @import("instance_bridge.zig");
const shadows = @import("shadow_hosts.zig");
const slots = @import("slot_helpers.zig");
const style = @import("style/engine.zig");
const focused_area = @import("focused_area.zig");
const NodeBase = @import("node_base.zig").NodeBase;
const Instance = runtime.Instance;
const Allocator = std.mem.Allocator;

pub const Role = roles.Role;

const eq = a11y.eq;
const oneOf = a11y.oneOf;
const attribute = a11y.attribute;
const localName = a11y.localName;
const isHtml = a11y.isHtml;
const spaces = " \t\n\r\x0c";

/// What the HTML host answers that the DOM does not know (dom does not
/// import html): the devtools domain supplies html.focus and the forms'
/// disabledness.
pub const Options = struct {
    /// HTML 6.6.2: a focusable area.
    is_focusable: *const fn (*Instance) bool,
    /// HTML 6.3 inertness (with CSS UI 4's interactivity).
    is_inert: *const fn (*Instance) bool,
    /// HTML 4.15 "actually disabled".
    is_disabled: *const fn (*Instance) bool,

    fn names(self: Options) a11y.Options {
        return .{ .is_focusable = self.is_focusable };
    }
};

pub const Index = u32;

/// The pseudo-elements that get objects, with the keys CDP's ids use for
/// them (devtools NodeIds.pseudoKey: ::before 1, ::after 2, ::marker 3).
pub const PseudoKind = enum(u3) {
    before = 1,
    after = 2,
    marker = 3,

    fn name(self: PseudoKind) []const u8 {
        return @tagName(self);
    }
};

/// What an object stands for.
pub const Source = union(enum) {
    /// A Document, Element or Text.
    node: *Instance,
    /// An element's ::before, ::after or ::marker (a PseudoElement in Blink,
    /// with its own DOMNodeId).
    pseudo: struct { element: *Instance, kind: PseudoKind },
    /// A nodeless object (Blink: a layout object with no node - a
    /// pseudo-element's text - or an inline text box): the n-th nodeless
    /// child of its parent.
    nodeless: u32,
};

/// Blink's ignored reasons (AXIgnoredReason), named as CDP's AXPropertyName.
pub const Reason = enum {
    activeModalDialog,
    ariaHiddenElement,
    ariaHiddenSubtree,
    emptyAlt,
    emptyText,
    inertElement,
    inertSubtree,
    labelContainer,
    labelFor,
    notRendered,
    notVisible,
    presentationalRole,
    probablyPresentational,
    uninteresting,
};

pub const IgnoredReason = struct {
    reason: Reason,
    /// The object the reason names (the aria-hidden root, the labelled
    /// control), when it has one.
    related: ?*Instance = null,
};

pub const Node = struct {
    source: Source,
    parent: ?Index = null,
    /// The role CDP sends for the object when it is not ignored
    /// (ComputeFinalRoleForSerialization).
    role: Role,
    /// The role before ARIA (NativeRoleIgnoringAria).
    native_role: Role = .Unknown,
    /// The role an ARIA role attribute gave, or Unknown.
    aria_role: Role = .Unknown,
    ignored: bool = false,
    reasons: []const IgnoredReason = &.{},
    /// ChildrenIncludingIgnored, in order.
    children: std.ArrayListUnmanaged(Index) = .empty,
    /// StaticText, LineBreak, InlineTextBox: the text as rendered.
    text: []const u8 = "",
    /// Hidden by style (Blink cached_is_hidden_via_style_).
    hidden_via_style: bool = false,
    /// A layout object: has a box (or, for a Text, a LayoutText).
    has_layout: bool = false,
    /// Part of a label or description (IsUsedForLabelOrDescription).
    used_for_label: bool = false,
    /// In the tree (IsIncludedInTree). An object that is not is kept only to
    /// be found by its node (getPartialAXTree's inspected node): it is no
    /// one's child and has none.
    included: bool = true,
};

/// One document's tree. All of it is in `arena`.
pub const Tree = struct {
    arena: Allocator,
    options: Options,
    document: *Instance,
    nodes: std.ArrayListUnmanaged(Node) = .empty,
    by_node: address_map.AddressHashMapUnmanaged(*Instance, Index) = .empty,
    names: a11y.Names,
    /// The ids an aria-labelledby or aria-describedby names (Blink's
    /// AXRelationCache IsARIALabelOrDescription), collected once.
    label_targets: std.StringHashMapUnmanaged(void) = .empty,
    /// Each block's line items, made once (renderedText's line edges).
    line_items: address_map.AddressHashMapUnmanaged(*Instance, []const LineItem) = .empty,
    /// Whether each white space Text has a LayoutText, as decided: the
    /// decision reads the previous in-flow sibling's, so a run of white space
    /// siblings (an SVG between comments) must decide each once, not again
    /// for every later one - svg-aam/role/roles.html's 60 comment-separated
    /// runs took the tree past the harness timeout without this.
    whitespace_layout: address_map.AddressHashMapUnmanaged(*Instance, bool) = .empty,

    /// Build `document`'s tree (Blink: UpdateAXForAllDocuments, then the
    /// root's descendants walked).
    pub fn build(arena: Allocator, document: *Instance, options: Options) !Tree {
        var tree: Tree = .{
            .arena = arena,
            .options = options,
            .document = document,
            .names = try a11y.Names.init(arena, document, options.names()),
        };
        try tree.nodes.append(arena, .{ .source = .{ .node = document }, .role = .RootWebArea, .native_role = .RootWebArea, .has_layout = true });
        try tree.by_node.put(arena, document, 0);
        try tree.collectLabelTargets(bridge.getNodeBase(document).?);
        try tree.addChildren(0, document, .{});
        return tree;
    }

    pub fn root(self: *const Tree) Index {
        _ = self;
        return 0;
    }

    pub fn node(self: *const Tree, index: Index) *Node {
        return &self.nodes.items[index];
    }

    /// The object of a DOM node, when it is in the tree.
    pub fn indexOf(self: *const Tree, dom_node: *Instance) ?Index {
        return self.by_node.get(dom_node);
    }

    /// The DOM node of an object, when it has one.
    pub fn domNode(self: *const Tree, index: Index) ?*Instance {
        return switch (self.nodes.items[index].source) {
            .node => |n| n,
            else => null,
        };
    }

    // ========================================================================
    // Children (AXNodeObject::AddChildrenImpl)
    // ========================================================================

    /// What a parent hands down while its children are added.
    const Inherited = struct {
        hidden_via_style: bool = false,
        /// The parent's role (ruby annotations, list markers).
        parent_role: Role = .Unknown,
        /// Inside a label element (its children stay in the tree).
        in_label: bool = false,
        /// The parent is part of a label or description.
        used_for_label: bool = false,
        /// The parent is hidden: by style or aria-hidden.
        hidden: bool = false,
        /// Under an ignored <label> through ignored objects only.
        in_ignored_label: bool = false,
    };

    const Child = union(enum) {
        node: *Instance,
        pseudo: PseudoKind,
    };

    /// Add `dom`'s children to object `owner` (an object in the tree),
    /// flattening those not in the tree into it.
    fn addChildren(self: *Tree, owner: Index, dom: *Instance, inherited: Inherited) anyerror!void {
        const base = bridge.getNodeBase(dom) orelse return;
        if (base.node_type == NodeBase.ELEMENT_NODE) {
            // An image with a map: its areas are its children
            // (AXNodeObject::AddImageMapChildren, AXImageMapLink).
            if (isHtml(dom) and eq(localName(dom), "img")) try self.addImageMapChildren(owner, dom);
            if (!canHaveChildren(dom)) return;
            // Children of frames are never part of layout (AddNodeChildren).
            if (isFrame(dom)) return;
        }
        // A menu-list select's options are in its pop-up (Blink: the UA
        // shadow tree's picker, role MenuListPopup), kept in the tree while
        // the pop-up is closed ("keep structure of <select size=1>").
        // Crane has no UA shadow tree: the pop-up is a nodeless object.
        var into = owner;
        if (base.node_type == NodeBase.ELEMENT_NODE and isHtml(dom) and eq(localName(dom), "select") and usesMenuList(dom)) {
            into = @intCast(self.nodes.items.len);
            try self.nodes.append(self.arena, .{ .source = .{ .nodeless = 0 }, .parent = owner, .role = .MenuListPopup, .native_role = .MenuListPopup, .has_layout = true });
            try self.nodes.items[owner].children.append(self.arena, into);
        }
        var children: std.ArrayListUnmanaged(Child) = .empty;
        try self.flatChildren(dom, &children);
        for (children.items) |child| switch (child) {
            .node => |n| try self.addNodeChild(into, n, inherited, false),
            .pseudo => |kind| try self.addPseudoChild(into, dom, kind, inherited),
        };
        // AddOwnedChildren: the owner adds every node it owns, last.
        if (base.node_type == NodeBase.ELEMENT_NODE) {
            for (try a11y.related(self.arena, dom, .owns)) |owned| {
                if (self.names.ownerOf(owned) == dom) try self.addNodeChild(owner, owned, inherited, true);
            }
        }
    }

    /// The areas of the map an <img usemap> names, each an AXImageMapLink:
    /// a link when it has an href, else a generic container
    /// (AXImageMapLink::NativeRoleIgnoringAria; html-aam/area-role.html:
    /// Chrome 157, Firefox 160 and Safari 27.2 all answer link).
    fn addImageMapChildren(self: *Tree, owner: Index, img: *Instance) !void {
        const usemap = std.mem.trim(u8, attribute(img, "usemap") orelse return, spaces);
        if (usemap.len < 2 or usemap[0] != '#') return;
        const name = usemap[1..];
        const map = findMap(bridge.getNodeBase(self.document).?, name) orelse return;
        var at = nextInSubtree(bridge.getNodeBase(map).?, bridge.getNodeBase(map).?);
        while (at) |current| : (at = nextInSubtree(current, bridge.getNodeBase(map).?)) {
            const area = a11y.instance(current) orelse continue;
            if (current.node_type != NodeBase.ELEMENT_NODE or !isHtml(area) or !eq(localName(area), "area")) continue;
            if (self.by_node.contains(area)) continue;
            const role: Role = if (attribute(area, "href") != null) .Link else .GenericContainer;
            const index = try self.appendNode(owner, .{ .source = .{ .node = area }, .role = role, .native_role = role, .has_layout = true });
            try self.by_node.put(self.arena, area, index);
        }
    }

    /// LayoutTreeBuilderTraversal's children: ::marker and ::before, then
    /// the flat tree's children (a host's shadow root's, a slot's assigned
    /// nodes or its fallback), then ::after.
    fn flatChildren(self: *Tree, dom: *Instance, out: *std.ArrayListUnmanaged(Child)) !void {
        const base = bridge.getNodeBase(dom) orelse return;
        const is_element = base.node_type == NodeBase.ELEMENT_NODE;
        const pseudos: style.GeneratedPseudos = if (is_element) style.generatedPseudos(dom) else .{};
        if (pseudos.marker) try out.append(self.arena, .{ .pseudo = .marker });
        if (pseudos.before) try out.append(self.arena, .{ .pseudo = .before });
        if (is_element) if (shadows.rootForHost(dom)) |shadow| {
            try appendChildNodes(self.arena, bridge.getNodeBase(shadow) orelse return, out);
            if (pseudos.after) try out.append(self.arena, .{ .pseudo = .after });
            return;
        };
        if (slots.slotState(base)) |slot| if (slot.hasAssignedNodes()) {
            for (slot.assigned_nodes.items) |ref| if (ref.get()) |assigned| if (a11y.instance(assigned)) |n| try out.append(self.arena, .{ .node = n });
            if (pseudos.after) try out.append(self.arena, .{ .pseudo = .after });
            return;
        };
        try appendChildNodes(self.arena, base, out);
        if (pseudos.after) try out.append(self.arena, .{ .pseudo = .after });
    }

    fn appendChildNodes(arena: Allocator, base: *NodeBase, out: *std.ArrayListUnmanaged(Child)) !void {
        var at = base.firstChild();
        while (at) |current| : (at = current.next_sibling) {
            if (a11y.instance(current)) |n| try out.append(arena, .{ .node = n });
        }
    }

    /// AddNodeChild: an object for `dom` under `owner`, or its children in
    /// its place when it is not in the tree.
    fn addNodeChild(self: *Tree, owner: Index, dom: *Instance, inherited: Inherited, from_owns: bool) anyerror!void {
        // An owned node is its owner's child, not its natural parent's.
        if (!from_owns and self.names.ownerOf(dom) != null) return;
        const base = bridge.getNodeBase(dom) orelse return;
        const kind = base.node_type;
        if (kind != NodeBase.ELEMENT_NODE and kind != NodeBase.TEXT_NODE and kind != NodeBase.CDATA_SECTION_NODE) return;
        if (try self.pruned(dom)) return;
        var object = try self.objectFor(dom, inherited);
        object.parent = owner;
        object.used_for_label = try self.usedForLabel(dom, &object, inherited);
        const included = from_owns or !object.ignored or try self.ignoredButIncluded(dom, &object);
        const next: Inherited = .{
            .hidden_via_style = object.hidden_via_style,
            .parent_role = object.role,
            .in_label = isHtml(dom) and eq(localName(dom), "label"),
            .used_for_label = object.used_for_label,
            .in_ignored_label = object.ignored and (object.role == .LabelText or inherited.in_ignored_label),
            .hidden = object.hidden_via_style or (object.ignored and object.reasons.len > 0 and (object.reasons[0].reason == .ariaHiddenElement or object.reasons[0].reason == .ariaHiddenSubtree)),
        };
        if (!included) {
            // Kept for lookup only (Blink's cache has the object; the tree
            // does not).
            object.included = false;
            try self.by_node.put(self.arena, dom, @intCast(self.nodes.items.len));
            try self.nodes.append(self.arena, object);
            // InsertChild: an object not in the tree gives its children to
            // the nearest ancestor that is.
            if (kind == NodeBase.ELEMENT_NODE) try self.addChildren(owner, dom, next);
            return;
        }
        const index: Index = @intCast(self.nodes.items.len);
        try self.nodes.append(self.arena, object);
        try self.by_node.put(self.arena, dom, index);
        try self.nodes.items[owner].children.append(self.arena, index);
        if (kind == NodeBase.ELEMENT_NODE) {
            try self.addChildren(index, dom, next);
        } else if (!object.ignored) {
            try self.addInlineTextBoxes(index);
        }
        if (object.role == .LineBreak and !object.ignored) try self.addInlineTextBoxes(index);
    }

    // ========================================================================
    // Which nodes get objects (DetermineAXObjectType)
    // ========================================================================

    /// Whether `dom` and its subtree get no object at all.
    fn pruned(self: *Tree, dom: *Instance) !bool {
        const base = bridge.getNodeBase(dom).?;
        if (base.node_type == NodeBase.ELEMENT_NODE) {
            if (isHtml(dom)) {
                const tag = localName(dom);
                // IsSubtreePrunedForAccessibility.
                if (oneOf(tag, .{ "map", "col", "colgroup", "title" })) return true;
                if (eq(tag, "area")) {
                    const p = base.parent_node orelse return true;
                    const parent_node = a11y.instance(p) orelse return true;
                    if (!eq(localName(parent_node), "map")) return true;
                }
                if (eq(tag, "slot") and slots.slotState(base) != null) {
                    // IsRelevantSlotElement: assigned nodes or fallback.
                    const slot = slots.slotState(base).?;
                    if (!slot.hasAssignedNodes() and base.firstChild() == null) return true;
                }
            }
            if (try hasBox(dom)) return false;
            // Not rendered: pruned inside head, style, script, noframes, a
            // frame's DOM children (IsInPrunableHiddenContainerInclusive).
            return inPrunableContainer(dom);
        }
        // Text.
        if (try self.hasLayoutText(dom)) return !try self.layoutTextRelevant(dom);
        // IsHiddenTextNodeRelevantForAccessibility.
        const p = base.parent_node orelse return true;
        const parent_element = a11y.instance(p) orelse return true;
        if (isFrame(parent_element)) return true;
        if (bridge.getNodeBase(parent_element).?.node_type != NodeBase.ELEMENT_NODE) return true;
        var value = try interfaces.CharacterData.get_data(dom);
        defer value.deinit(dom.ctx.allocator);
        if (std.mem.trim(u8, value.asSlice(), spaces).len == 0) return true;
        return inPrunableContainer(dom);
    }

    fn inPrunableContainer(dom: *Instance) bool {
        var at: ?*NodeBase = bridge.getNodeBase(dom);
        while (at) |current| : (at = current.parent_node) {
            const n = a11y.instance(current) orelse continue;
            if (bridge.getNodeBase(n).?.node_type != NodeBase.ELEMENT_NODE) continue;
            if (isHtml(n) and oneOf(localName(n), .{ "head", "style", "script", "noframes" })) return true;
            if (isFrame(n)) return true;
            if (!isHtml(n) and eq(localName(n), "style")) return true;
        }
        return false;
    }

    /// Whether `text` has a LayoutText: its parent renders children and
    /// Blink's layout tree builder makes one for it.
    fn hasLayoutText(self: *Tree, text: *Instance) !bool {
        const p = a11y.parent(text) orelse return false;
        if (bridge.getNodeBase(p).?.node_type != NodeBase.ELEMENT_NODE) return false;
        if (!rendersChildren(p)) return false;
        if (isSvg(p) and !svgTakesText(p)) return false;
        if (!try rendered(p)) return false;
        var value = try interfaces.CharacterData.get_data(text);
        defer value.deinit(text.ctx.allocator);
        const bytes = value.asSlice();
        if (bytes.len == 0) return false;
        if (std.mem.trim(u8, bytes, spaces).len != 0) return true;
        return whitespaceNeedsLayout(self, text, p);
    }

    /// IsLayoutTextRelevantForAccessibility for a Text with a LayoutText:
    /// anything but collapsible white space; white space only between
    /// inline content in the same block (CanIgnoreSpace).
    fn layoutTextRelevant(self: *Tree, text: *Instance) !bool {
        _ = self;
        var value = try interfaces.CharacterData.get_data(text);
        defer value.deinit(text.ctx.allocator);
        const bytes = value.asSlice();
        if (std.mem.trim(u8, bytes, spaces).len != 0) return true;
        const p = a11y.parent(text) orelse return false;
        if (preservesWhiteSpace(p)) return true;
        return canKeepSpace(text);
    }

    // ========================================================================
    // One object: role and ignored state
    // ========================================================================

    fn objectFor(self: *Tree, dom: *Instance, inherited: Inherited) !Node {
        const base = bridge.getNodeBase(dom).?;
        if (base.node_type != NodeBase.ELEMENT_NODE) return self.textObject(dom, inherited);
        var object: Node = .{ .source = .{ .node = dom }, .role = .Unknown };
        object.has_layout = try hasBox(dom);
        object.native_role = try self.nativeRole(dom, object.has_layout);
        object.aria_role = try self.ariaRole(dom, object.native_role);
        const role = if (object.aria_role != .Unknown) object.aria_role else object.native_role;
        object.hidden_via_style = try hiddenViaStyle(dom, object.has_layout);
        object.role = role;
        var reasons: std.ArrayListUnmanaged(IgnoredReason) = .empty;
        object.ignored = try self.computeIgnored(dom, &object, &reasons);
        object.reasons = reasons.items;
        object.role = try self.finalRole(dom, &object, inherited);
        return object;
    }

    fn textObject(self: *Tree, text: *Instance, inherited: Inherited) !Node {
        var object: Node = .{ .source = .{ .node = text }, .role = .StaticText, .native_role = .StaticText };
        object.has_layout = try self.hasLayoutText(text);
        object.hidden_via_style = inherited.hidden_via_style;
        var reasons: std.ArrayListUnmanaged(IgnoredReason) = .empty;
        // ShouldIgnoreForHiddenOrInert, then ComputeIsIgnored for text.
        if (try self.names.ariaHidden(text)) {
            object.ignored = true;
            try self.ariaHiddenReasons(text, &reasons);
        } else if (try self.inert(text)) {
            object.ignored = true;
            try reasons.append(self.arena, .{ .reason = .inertElement });
        } else if (object.hidden_via_style) {
            object.ignored = true;
            try reasons.append(self.arena, .{ .reason = if (object.has_layout) .notVisible else .notRendered });
        } else if (!object.has_layout) {
            object.ignored = true;
            try reasons.append(self.arena, .{ .reason = .notRendered });
        } else if (inherited.parent_role == .RubyAnnotation) {
            object.ignored = true;
        } else if (inherited.in_ignored_label and inherited.used_for_label) {
            // Text inside an ignored <label> (ComputeIsIgnored's walk up
            // the ignored ancestors to a LabelText).
            object.ignored = true;
            try reasons.append(self.arena, .{ .reason = .presentationalRole });
        }
        object.reasons = reasons.items;
        object.text = try self.renderedText(text);
        return object;
    }

    /// The aria-hidden reasons: the root names itself, its descendants it.
    fn ariaHiddenReasons(self: *Tree, dom: *Instance, reasons: *std.ArrayListUnmanaged(IgnoredReason)) !void {
        var at: ?*Instance = dom;
        while (at) |element| : (at = self.names.accessibilityParent(element)) {
            if (try a11y.effective(self.arena, element, "aria-hidden", "ariaHidden")) |value| {
                if (std.ascii.eqlIgnoreCase(value, "true")) {
                    if (element == dom) {
                        try reasons.append(self.arena, .{ .reason = .ariaHiddenElement });
                    } else {
                        try reasons.append(self.arena, .{ .reason = .ariaHiddenSubtree, .related = element });
                    }
                    return;
                }
            }
        }
    }

    fn inert(self: *Tree, dom: *Instance) !bool {
        const base = bridge.getNodeBase(dom).?;
        if (base.node_type == NodeBase.ELEMENT_NODE) return self.options.is_inert(dom);
        const p = a11y.parent(dom) orelse return false;
        return self.options.is_inert(p);
    }

    /// AXNodeObject::ComputeIsIgnored, its reasons in `reasons`.
    fn computeIgnored(self: *Tree, dom: *Instance, object: *Node, reasons: *std.ArrayListUnmanaged(IgnoredReason)) !bool {
        // ShouldIgnoreForHiddenOrInert.
        if (try self.names.ariaHidden(dom)) {
            try self.ariaHiddenReasons(dom, reasons);
            return true;
        }
        if (try self.inert(dom)) {
            // ComputeIsInert: the inert root names itself, its subtree the root.
            try reasons.append(self.arena, .{ .reason = if (attribute(dom, "inert") != null) .inertElement else .inertSubtree });
            return true;
        }
        if (object.hidden_via_style) {
            try reasons.append(self.arena, .{ .reason = if (object.has_layout) .notVisible else .notRendered });
            return true;
        }
        const display_contents = try isDisplayContents(dom);
        if (!object.has_layout and !display_contents and !(isHtml(dom) and oneOf(localName(dom), .{ "area", "option" }))) {
            try reasons.append(self.arena, .{ .reason = .notRendered });
            return true;
        }
        switch (try self.includeBasedOnSemantics(dom, object, reasons)) {
            .include => return false,
            .ignore => return true,
            .default => {},
        }
        if (!object.has_layout) {
            try reasons.append(self.arena, .{ .reason = .uninteresting });
            return true;
        }
        // An iframe or embedded object (LayoutEmbeddedContent).
        if (isFrame(dom) or (isHtml(dom) and oneOf(localName(dom), .{ "embed", "object" }))) return false;
        if (eq(localName(dom), "br") and isHtml(dom)) return false;
        // Positioned elements are kept for their bounding boxes. Crane has no
        // scroll containers to keep (geometry): only position is read.
        if (try isPositioned(dom)) return false;
        // A block flow that directly parents inline children is kept.
        if (try parentsInlineChildren(dom)) return false;
        try reasons.append(self.arena, .{ .reason = .uninteresting });
        return true;
    }

    const Inclusion = enum { include, ignore, default };

    /// AXNodeObject::ShouldIncludeBasedOnSemantics.
    fn includeBasedOnSemantics(self: *Tree, dom: *Instance, object: *Node, reasons: *std.ArrayListUnmanaged(IgnoredReason)) !Inclusion {
        const role = object.role;
        if (role == .None) {
            try reasons.append(self.arena, .{ .reason = .presentationalRole });
            return .ignore;
        }
        if (role == .RubyAnnotation) return .ignore;
        const tag = localName(dom);
        const html_element = isHtml(dom);
        // SVG (ShouldIncludeBasedOnSemantics' SVG block, before the rules
        // below): a <symbol>'s subtree is a template, not rendered where it
        // is; a non-empty outermost <svg> is kept (clients may treat it as an
        // image); so is an element with a direct <title> or <desc> child
        // (SVG-AAM "Including elements": css-display/accessibility/
        // display-contents-role-and-label.html's display:contents <g>,
        // group in Chrome 157, Firefox 160 and Safari 27.2).
        if (isSvg(dom)) {
            var at: ?*Instance = dom;
            while (at) |n| : (at = a11y.parent(n)) {
                if (isSvg(n) and eq(localName(n), "symbol")) return .ignore;
            }
            if (object.native_role == .SvgRoot and object.has_layout and firstElementChild(dom) != null) return .include;
            if (a11y.firstChildNamed(dom, "title") != null or a11y.firstChildNamed(dom, "desc") != null) return .include;
        }
        if (isTableLike(role) or isTableRowLike(role) or isTableCellLike(role) or (html_element and oneOf(tag, .{ "thead", "tfoot" }))) return .include;
        if (html_element and eq(tag, "html")) {
            try reasons.append(self.arena, .{ .reason = .uninteresting });
            return .ignore;
        }
        if (!(html_element and eq(tag, "body")) and self.options.is_focusable(dom)) return .include;
        if (role == .Link) return .include;
        if (isHeading(role)) return .include;
        if (html_element and oneOf(tag, .{ "header", "footer" })) return .include;
        // AXNodeObject::IsControl: a form control element, or an ARIA
        // control role.
        if (isFormControlElement(dom) or isControl(object.aria_role)) return .include;
        if (html_element and eq(tag, "optgroup")) return .include;
        if (object.aria_role != .Unknown or attribute(dom, "role") != null and object.aria_role != .Unknown) return .include;
        if (isEditableRoot(dom)) return .include;
        if (isCustomElement(dom)) {
            if (try self.includeCustomElement(dom, role)) return .include;
            return .ignore;
        }
        if (html_element and eq(tag, "legend")) return .include;
        if (alwaysIncluded(role)) return .include;
        if (html_element and eq(tag, "hgroup")) return .include;
        if (hasAnyAria(dom)) return .include;
        if (attribute(dom, "title")) |title| if (title.len > 0) return .include;
        if (role == .Image and !isSvg(dom)) {
            const alt = attribute(dom, "alt");
            if (alt == null or alt.?.len > 0) return .include;
            try reasons.append(self.arena, .{ .reason = .emptyAlt });
            return .ignore;
        }
        if (isPotentialInPageLinkTarget(dom)) return .include;
        if (html_element and eq(tag, "span")) {
            try reasons.append(self.arena, .{ .reason = .uninteresting });
            return .ignore;
        }
        if (html_element and eq(tag, "label")) {
            if (try self.isRedundantLabel(dom)) |control| {
                try reasons.append(self.arena, .{ .reason = .labelFor, .related = control });
                return .ignore;
            }
            return .include;
        }
        return .default;
    }

    /// A custom element is ignored unless something makes it meaningful
    /// (AXNodeObject::ShouldIncludeCustomElement).
    fn includeCustomElement(self: *Tree, dom: *Instance, role: Role) !bool {
        if (role != .GenericContainer) return true;
        if (shadows.rootForHost(dom) == null) return true;
        if (attribute(dom, "aria-live") != null) return true;
        return self.options.is_focusable(dom);
    }

    /// AXNodeObject::IsRedundantLabel: the label of a visible checkbox or
    /// radio that its label names (IsNameFromLabelElement: no aria-labelledby
    /// elements, no aria-label), holding no element but that control - the
    /// control already speaks it. Returns the control.
    fn isRedundantLabel(self: *Tree, label: *Instance) !?*Instance {
        const control = (try interfaces.HTMLLabelElement.get_control(label)) orelse return null;
        if (control.stateAs(interfaces.HTMLInputElement.State) == null) return null;
        // A laid-out control whose visibility is visible.
        if (!try hasBox(control)) return null;
        const computed = (try style.computedStyle(control, null)) orelse return null;
        if (computed.keyword(.visibility) != .visible) return null;
        var kind = try interfaces.HTMLInputElement.get_type(control);
        defer kind.deinit(control.ctx.allocator);
        if (!oneOf(kind.asSlice(), .{ "checkbox", "radio" })) return null;
        // IsNameFromAriaAttribute.
        if ((try a11y.related(self.arena, control, .labelledby)).len > 0) return null;
        if (try a11y.effective(self.arena, control, "aria-label", "ariaLabel")) |value| if (std.mem.trim(u8, value, spaces).len > 0) return null;
        // The first element child: none, or the control alone.
        const base = bridge.getNodeBase(label).?;
        var first: ?*NodeBase = base.firstChild();
        while (first) |child| : (first = child.next_sibling) if (child.node_type == NodeBase.ELEMENT_NODE) break;
        const child = first orelse return control;
        if (child != bridge.getNodeBase(control).?) return null;
        var next = child.next_sibling;
        while (next) |sibling| : (next = sibling.next_sibling) if (sibling.node_type == NodeBase.ELEMENT_NODE) return null;
        return control;
    }

    /// ComputeIsIgnoredButIncludedInTree, for an ignored element or text.
    fn ignoredButIncluded(self: *Tree, dom: *Instance, object: *const Node) !bool {
        const base = bridge.getNodeBase(dom).?;
        // An aria-owns owner is always in the tree.
        if (base.node_type == NodeBase.ELEMENT_NODE and attribute(dom, "aria-owns") != null) return true;
        if (isHtml(dom) and eq(localName(dom), "label")) return true;
        const dom_parent_base = base.parent_node orelse return true;
        const dom_parent = a11y.instance(dom_parent_base) orelse return true;
        // The flat-tree parent differs from the DOM parent: slotted nodes and
        // a shadow root's children.
        if (a11y.parent(dom) != dom_parent) return true;
        if (isHtml(dom_parent) and eq(localName(dom_parent), "label") and !(isHtml(dom) and eq(localName(dom), "span"))) return true;
        if (isHtml(dom_parent) and oneOf(localName(dom_parent), .{ "map", "rt" })) return true;
        if (base.node_type == NodeBase.ELEMENT_NODE) {
            // The parent of a ::before, ::after or ::marker.
            const pseudos = style.generatedPseudos(dom);
            if (pseudos.before or pseudos.after or pseudos.marker) return true;
        }
        if (object.used_for_label) {
            if (!object.has_layout) {
                if (!(isHtml(dom) and oneOf(localName(dom), .{ "datalist", "option" }))) return true;
            } else {
                if (object.hidden_via_style) return true;
                if (try self.names.ariaHidden(dom)) return !isFrame(dom);
            }
        }
        if (base.node_type != NodeBase.ELEMENT_NODE) return false;
        if (isHtml(dom) and eq(localName(dom), "html")) return true;
        if (object.role == .Video or object.role == .Audio or object.role == .Menu) return true;
        // Line breaking objects: blocks and br, when visible (IsVisible: not
        // inert either - Chrome 157 leaves an inert block out, the trace's
        // hidden page).
        if (!object.hidden_via_style and !try self.inert(dom) and !try self.names.ariaHidden(dom) and isLineBreakingObject(dom, object.role)) return true;
        if (isHtml(dom) and oneOf(localName(dom), .{ "rt", "table", "tbody", "tr", "td", "th" })) return true;
        if (attribute(dom, "lang") != null) return true;
        return false;
    }

    /// ComputeIsUsedForLabelOrDescription: a <label>, the target of a
    /// naming or description relation, a visible object that takes its name
    /// from its contents, or a descendant of one that does not hide itself.
    fn usedForLabel(self: *Tree, dom: *Instance, object: *const Node, inherited: Inherited) !bool {
        const base = bridge.getNodeBase(dom).?;
        if (base.node_type == NodeBase.ELEMENT_NODE) {
            if (isHtml(dom) and eq(localName(dom), "label")) return true;
            if (attribute(dom, "id")) |id| if (id.len > 0 and self.label_targets.contains(id)) return true;
            if ((!object.ignored or self.options.is_focusable(dom)) and supportsNameFromContents(object.role)) return true;
        }
        if (object.role == .Group) return false;
        if (!inherited.used_for_label) return false;
        const hidden = object.hidden_via_style or try self.names.ariaHidden(dom);
        return !hidden or inherited.hidden;
    }

    fn collectLabelTargets(self: *Tree, scope: *NodeBase) !void {
        var at = scope.firstChild();
        while (at) |current| : (at = nextNode(current, scope)) {
            if (current.node_type != NodeBase.ELEMENT_NODE) continue;
            const n = a11y.instance(current) orelse continue;
            inline for (.{ "aria-labelledby", "aria-describedby", "aria-labeledby" }) |name| {
                if (attribute(n, name)) |value| {
                    var tokens = std.mem.tokenizeAny(u8, value, spaces);
                    while (tokens.next()) |token| try self.label_targets.put(self.arena, token, {});
                }
            }
            if (shadows.rootForHost(n)) |shadow| try self.collectLabelTargets(bridge.getNodeBase(shadow) orelse continue);
        }
    }

    // ========================================================================
    // Roles
    // ========================================================================

    /// AXNodeObject::NativeRoleIgnoringAria.
    fn nativeRole(self: *Tree, dom: *Instance, has_layout: bool) !Role {
        const tag = localName(dom);
        if (!isHtml(dom)) {
            if (isSvg(dom)) {
                if (eq(tag, "svg")) return if (bridge.getNodeBase(dom).?.parent_node != null and svgParent(dom)) .Group else .SvgRoot;
                if (eq(tag, "g")) return .Group;
                // An SVG link by href or xlink:href (SVGAElement's
                // IsLinkable; svg-aam/role/roles.html: link in all three).
                if (eq(tag, "a")) return if (attribute(dom, "href") != null or xlinkHref(dom) != null) .Link else .Group;
                if (oneOf(tag, .{ "rect", "circle", "ellipse", "line", "path", "polygon", "polyline" })) return .GraphicsSymbol;
                if (eq(tag, "image")) return .Image;
                if (eq(tag, "use")) return .GraphicsObject;
                if (eq(tag, "foreignObject")) return .Group;
                return .GenericContainer;
            }
            if (eq(tag, "math")) return .MathMLMath;
            return .GenericContainer;
        }
        if (eq(tag, "img")) return .Image;
        if (eq(tag, "a")) return if (attribute(dom, "href") != null) .Link else .GenericContainer;
        if (eq(tag, "button")) return buttonRole(dom);
        if (eq(tag, "details")) return .Details;
        if (eq(tag, "summary")) {
            const p = a11y.parent(dom) orelse return .GenericContainer;
            // LayoutTreeBuilderTraversal::Parent: only the details' first
            // summary child is slotted into its summary slot, whose parent
            // is the details; any other summary sits in the default slot, in
            // the details' content (html-aam/summary.html: Chrome 157,
            // Firefox 160 and Safari 27.2 all answer generic).
            if (isHtml(p) and eq(localName(p), "details") and a11y.firstChildNamed(p, "summary") == dom) {
                return if (attributeLength(p, "name") == 0) .DisclosureTriangle else .DisclosureTriangleGrouped;
            }
            return .GenericContainer;
        }
        if (eq(tag, "table")) return if (try self.isDataTable(dom)) .Table else .LayoutTable;
        if (eq(tag, "tr")) return self.tableRowRole(dom);
        if (oneOf(tag, .{ "td", "th" })) return self.tableCellRole(dom);
        if (oneOf(tag, .{ "thead", "tbody", "tfoot" })) return self.tableSectionRole(dom);
        if (eq(tag, "input")) {
            var value = try interfaces.HTMLInputElement.get_type(dom);
            defer value.deinit(dom.ctx.allocator);
            const kind = value.asSlice();
            if (!eq(kind, "color") and (try interfaces.HTMLInputElement.get_list(dom)) != null) return .TextFieldWithComboBox;
            if (oneOf(kind, .{ "button", "reset", "submit" })) return buttonRole(dom);
            if (eq(kind, "checkbox")) return if (attribute(dom, "switch") != null) .Switch else .CheckBox;
            if (eq(kind, "date")) return .Date;
            if (oneOf(kind, .{ "datetime-local", "month", "week" })) return .DateTime;
            if (oneOf(kind, .{ "file", "image" })) return .Button;
            if (eq(kind, "radio")) return .RadioButton;
            if (eq(kind, "number")) return .SpinButton;
            if (eq(kind, "range")) return .Slider;
            if (eq(kind, "search")) return .SearchBox;
            if (eq(kind, "color")) return .ColorWell;
            if (eq(kind, "time")) return .InputTime;
            return .TextField;
        }
        if (eq(tag, "select")) return if (usesMenuList(dom)) .ComboBoxSelect else .ListBox;
        if (eq(tag, "option")) {
            const select = owningSelect(dom);
            return if (select != null and usesMenuList(select.?)) .MenuListOption else .ListBoxOption;
        }
        if (eq(tag, "optgroup")) return .Group;
        if (eq(tag, "textarea")) return .TextField;
        if (tag.len == 2 and tag[0] == 'h' and tag[1] >= '1' and tag[1] <= '6') return .Heading;
        if (eq(tag, "div")) return self.roleFromLayout(dom, has_layout);
        if (oneOf(tag, .{ "menu", "ul", "ol", "dir" })) return .List;
        if (eq(tag, "li")) return if (ignoredListItem(dom)) .None else .ListItem;
        if (eq(tag, "meter")) return .Meter;
        if (eq(tag, "progress")) return .ProgressIndicator;
        if (eq(tag, "output")) return .Status;
        if (eq(tag, "p")) return .Paragraph;
        if (eq(tag, "label")) return .LabelText;
        if (eq(tag, "legend")) return .Legend;
        if (eq(tag, "ruby")) return .Ruby;
        if (eq(tag, "dl")) return .DescriptionList;
        if (eq(tag, "audio")) return .Audio;
        if (eq(tag, "video")) return .Video;
        if (eq(tag, "dd")) return .Definition;
        if (oneOf(tag, .{ "dfn", "dt" })) return .Term;
        if (oneOf(tag, .{ "rp", "rt" })) return .RubyAnnotation;
        if (eq(tag, "form")) return .Form;
        if (eq(tag, "abbr")) return .Abbr;
        if (eq(tag, "article")) return .Article;
        if (eq(tag, "code")) return .Code;
        if (eq(tag, "em")) return .Emphasis;
        if (eq(tag, "strong")) return .Strong;
        if (eq(tag, "search")) return .Search;
        if (oneOf(tag, .{ "del", "s" })) return .ContentDeletion;
        if (eq(tag, "ins")) return .ContentInsertion;
        if (eq(tag, "sub")) return .Subscript;
        if (eq(tag, "sup")) return .Superscript;
        if (eq(tag, "main")) return .Main;
        if (eq(tag, "mark")) return .Mark;
        if (eq(tag, "nav")) return .Navigation;
        if (eq(tag, "aside")) return .Complementary;
        if (eq(tag, "section")) return .Section;
        if (oneOf(tag, .{ "address", "hgroup" })) return .Group;
        if (eq(tag, "dialog")) return .Dialog;
        if (eq(tag, "html")) return .GenericContainer;
        if (oneOf(tag, .{ "iframe", "frame", "fencedframe" })) return .Iframe;
        if (eq(tag, "header")) return .Header;
        if (eq(tag, "footer")) return .Footer;
        if (eq(tag, "blockquote")) return .Blockquote;
        if (eq(tag, "caption")) return .Caption;
        if (eq(tag, "figcaption")) return .Figcaption;
        if (eq(tag, "figure")) return .Figure;
        if (eq(tag, "time")) return .Time;
        if (eq(tag, "embed")) return .EmbeddedObject;
        if (eq(tag, "object")) return .PluginObject;
        if (eq(tag, "hr")) return .Splitter;
        if (eq(tag, "fieldset")) return .Group;
        if (eq(tag, "br")) return .LineBreak;
        if (eq(tag, "canvas")) return .Canvas;
        return self.roleFromLayout(dom, has_layout);
    }

    /// RoleFromLayoutObjectOrNode, for what the element tags above leave.
    fn roleFromLayout(self: *Tree, dom: *Instance, has_layout: bool) !Role {
        _ = self;
        if (!has_layout) return .GenericContainer;
        const computed = (try style.computedStyle(dom, null)) orelse return .GenericContainer;
        const display = computed.display();
        if (display.list_item) return .ListItem;
        if (display.inner == .table and display.box == .normal) return .LayoutTable;
        if (display.box == .internal) switch (display.internal) {
            .table_row => return .LayoutTableRow,
            .table_cell => return .LayoutTableCell,
            else => {},
        };
        if (isHtml(dom) and attribute(dom, "role") == null) {
            if (attribute(dom, "popover") != null) return .Group;
            if (attribute(dom, "autofocus") != null or attribute(dom, "draggable") != null) return .Group;
        }
        return .GenericContainer;
    }

    /// AXObject::DetermineAriaRole: the first valid role token, with
    /// Chromium's context and presentational-conflict rules.
    fn ariaRole(self: *Tree, dom: *Instance, native: Role) !Role {
        const value = (try a11y.effective(self.arena, dom, "role", "role")) orelse return .Unknown;
        var role = try self.firstValidRole(dom, value, false);
        if ((role == .Form or role == .Region) and !try a11y.authorNamed(self.arena, dom) and attribute(dom, "aria-roledescription") == null) {
            return self.firstValidRole(dom, value, true);
        }
        if (role == .None) {
            if (isFrame(dom)) return .IframePresentational;
            if (self.options.is_focusable(dom) or supportsFocusAttr(dom)) return .Unknown;
            if (a11y.hasGlobalAria(dom) and !isCustomElement(dom)) return .Unknown;
        }
        if (role == .Button) role = buttonRole(dom);
        if (role == .ComboBoxGrouping) {
            if (native == .TextField or native == .SearchBox or native == .TextFieldWithComboBox) {
                role = .TextFieldWithComboBox;
            } else if (native == .ComboBoxSelect) {
                role = .Unknown;
            } else if (comboboxMenuButton(dom)) {
                role = .ComboBoxMenuButton;
            }
        }
        return role;
    }

    fn firstValidRole(self: *Tree, dom: *Instance, value: []const u8, ignore_form_and_region: bool) !Role {
        var tokens = std.mem.tokenizeAny(u8, value, spaces);
        while (tokens.next()) |token| {
            const role = ariaToInternal(token);
            if (role == .Unknown) continue;
            if (ignore_form_and_region and (role == .Form or role == .Region)) continue;
            if (!hasRequiredParentContext(self, dom, role)) continue;
            return role;
        }
        return .Unknown;
    }

    /// AXObject::ComputeFinalRoleForSerialization.
    fn finalRole(self: *Tree, dom: *Instance, object: *const Node, inherited: Inherited) !Role {
        _ = inherited;
        const role = object.role;
        switch (role) {
            .Header, .Footer => if (try self.landmarkDisallowed(dom, role)) return if (role == .Header) .SectionHeader else .SectionFooter,
            .Complementary => if (object.aria_role != .Complementary and try self.landmarkDisallowed(dom, role) and !try a11y.authorNamed(self.arena, dom)) return .GenericContainer,
            .Section => return if (try a11y.authorNamed(self.arena, dom)) .Region else .SectionWithoutName,
            .Cell => if (self.tableAncestorRole(dom)) |table| if (table == .Grid or table == .TreeGrid) return .GridCell,
            .GenericContainer => if (object.ignored and isCustomElement(dom)) return .None,
            else => {},
        }
        return role;
    }

    /// IsDescendantOfLandmarkDisallowedElement, by the DOM's sectioning
    /// ancestors (the roles Blink reads off its unignored ancestors).
    fn landmarkDisallowed(self: *Tree, dom: *Instance, role: Role) !bool {
        var at = a11y.parent(dom);
        while (at) |ancestor| : (at = a11y.parent(ancestor)) {
            if (bridge.getNodeBase(ancestor).?.node_type != NodeBase.ELEMENT_NODE) break;
            const ancestor_role = blk: {
                const native = try self.nativeRole(ancestor, true);
                const aria = try self.ariaRole(ancestor, native);
                break :blk if (aria != .Unknown) aria else native;
            };
            const disallowed = switch (ancestor_role) {
                .Article, .Complementary, .Navigation, .Section => true,
                .Main => role != .Complementary,
                else => false,
            };
            if (disallowed) return true;
        }
        return false;
    }

    fn tableAncestorRole(self: *Tree, dom: *Instance) ?Role {
        _ = self;
        var at = a11y.parent(dom);
        while (at) |ancestor| : (at = a11y.parent(ancestor)) {
            if (bridge.getNodeBase(ancestor).?.node_type != NodeBase.ELEMENT_NODE) return null;
            if (attribute(ancestor, "role")) |value| {
                var tokens = std.mem.tokenizeAny(u8, value, spaces);
                if (tokens.next()) |token| {
                    const role = ariaToInternal(token);
                    if (role == .Grid or role == .TreeGrid or role == .Table) return role;
                }
            }
            if (isHtml(ancestor) and eq(localName(ancestor), "table")) return .Table;
        }
        return null;
    }

    /// AXNodeObject::IsDataTable: markup decides (an ARIA role, editing, a
    /// summary, thead, tfoot or caption, rules, col elements, 20 rows or
    /// more, a th, a cell's headers/abbr/axis/scope). Blink then weighs the
    /// cells' borders and backgrounds and their laid-out sizes; Crane, with
    /// no boxes, answers a layout table there.
    fn isDataTable(self: *Tree, table: *Instance) !bool {
        _ = self;
        if (!try hasBox(table)) return true;
        if (attribute(table, "role") != null) return true;
        if (isEditableRoot(table)) return true;
        if (attributeLength(table, "summary") > 0) return true;
        if (attributeLength(table, "rules") > 0) return true;
        const base = bridge.getNodeBase(table).?;
        var rows: usize = 0;
        var at = base.firstChild();
        while (at) |current| : (at = current.next_sibling) {
            const n = a11y.instance(current) orelse continue;
            if (current.node_type != NodeBase.ELEMENT_NODE or !isHtml(n)) continue;
            const tag = localName(n);
            if (oneOf(tag, .{ "caption", "thead", "tfoot", "col", "colgroup" })) return true;
            if (eq(tag, "tbody") or eq(tag, "tr")) {
                var row_at: ?*NodeBase = if (eq(tag, "tr")) current else current.firstChild();
                while (row_at) |row_node| : (row_at = if (eq(tag, "tr")) null else row_node.next_sibling) {
                    const row = a11y.instance(row_node) orelse continue;
                    if (row_node.node_type != NodeBase.ELEMENT_NODE or !isHtml(row) or !eq(localName(row), "tr")) continue;
                    rows += 1;
                    var cell_at = row_node.firstChild();
                    while (cell_at) |cell_node| : (cell_at = cell_node.next_sibling) {
                        const cell = a11y.instance(cell_node) orelse continue;
                        if (cell_node.node_type != NodeBase.ELEMENT_NODE or !isHtml(cell)) continue;
                        if (eq(localName(cell), "th")) return true;
                        if (!eq(localName(cell), "td")) continue;
                        inline for (.{ "headers", "abbr", "axis", "scope" }) |name| if (attributeLength(cell, name) > 0) return true;
                    }
                }
            }
        }
        if (rows >= 20) return true;
        return false;
    }

    /// GetDOMTableAXAncestor's table: the nearest <table> ancestor, and
    /// whether it is a data table (Table) or a layout table.
    fn domTable(self: *Tree, element: *Instance) !?Role {
        var at = a11y.parent(element);
        while (at) |ancestor| : (at = a11y.parent(ancestor)) {
            if (bridge.getNodeBase(ancestor).?.node_type != NodeBase.ELEMENT_NODE) return null;
            if (isHtml(ancestor) and eq(localName(ancestor), "table")) {
                const native: Role = if (try self.isDataTable(ancestor)) .Table else .LayoutTable;
                const aria = try self.ariaRole(ancestor, native);
                return if (aria != .Unknown) aria else native;
            }
        }
        return null;
    }

    /// DetermineTableRowRole.
    fn tableRowRole(self: *Tree, row: *Instance) !Role {
        const table = (try self.domTable(row)) orelse return .GenericContainer;
        if (!isTableLike(table)) return .GenericContainer;
        return if (table == .LayoutTable) .LayoutTableRow else .Row;
    }

    /// DetermineTableCellRole: a cell of a row of a table.
    fn tableCellRole(self: *Tree, cell: *Instance) !Role {
        const row = a11y.parent(cell) orelse return .GenericContainer;
        if (!isHtml(row) or !eq(localName(row), "tr")) return .GenericContainer;
        // The row's role as its object has it - an explicit role=row too
        // (DetermineTableCellRole reads the parent object's RoleValue).
        const native_row = try self.tableRowRole(row);
        const aria_row = try self.ariaRole(row, native_row);
        const row_role = if (aria_row != .Unknown) aria_row else native_row;
        // And the row's own table ancestor must be table-like
        // (GetDOMTableAXAncestor of the row): a row inside a presentational
        // table keeps its cells generic even with role=row.
        const table = (try self.domTable(row)) orelse return .GenericContainer;
        if (!isTableLike(table)) return .GenericContainer;
        if (!isTableRowLike(row_role)) return .GenericContainer;
        if (row_role == .LayoutTableRow) return .LayoutTableCell;
        if (eq(localName(cell), "th")) {
            const scope = attribute(cell, "scope") orelse "";
            if (std.ascii.eqlIgnoreCase(scope, "row") or std.ascii.eqlIgnoreCase(scope, "rowgroup")) return .RowHeader;
            if (std.ascii.eqlIgnoreCase(scope, "col") or std.ascii.eqlIgnoreCase(scope, "colgroup")) return .ColumnHeader;
            return decideHeaderFromSiblings(cell);
        }
        return .Cell;
    }

    /// DetermineTableSectionRole.
    fn tableSectionRole(self: *Tree, section: *Instance) !Role {
        const table = (try self.domTable(section)) orelse return .GenericContainer;
        if (!isTableLike(table) or table == .LayoutTable) return .GenericContainer;
        return .RowGroup;
    }

    // ========================================================================
    // Pseudo-elements and nodeless objects
    // ========================================================================

    /// A ::before, ::after or ::marker (Blink: a PseudoElement, its
    /// children walked from its layout objects - AddPseudoElementChildren-
    /// FromLayoutTree), as Chrome 157 answers them (a11y1-chrome157-trace.txt):
    /// - content with CSS alt text is a StaticText of that text, with no
    ///   children (GetCSSAltText; an empty alt text makes it irrelevant);
    /// - other content: the pseudo-element ignored (uninteresting), a nodeless
    ///   StaticText for its text, a quote wrapped in an ignored anonymous
    ///   object (LayoutQuote);
    /// - a list item's ::marker is a ListMarker named by its text, the text
    ///   itself ignored (presentational); a summary's, or one of a list item
    ///   whose list has another role (ShouldIgnoreListItem), is ignored
    ///   presentational - its text ignored for a summary, kept otherwise.
    fn addPseudoChild(self: *Tree, owner: Index, element: *Instance, kind: PseudoKind, inherited: Inherited) !void {
        _ = inherited;
        const computed = (try style.computedStyle(element, kind.name())) orelse return;
        if (computed.display().box == .none) return;
        const hidden = computed.keyword(.visibility) == .hidden or computed.keyword(.visibility) == .collapse;
        const source: Source = .{ .pseudo = .{ .element = element, .kind = kind } };
        if (kind == .marker) return self.addMarker(owner, element, source, hidden);
        const value = computed.get(.content);
        if (value != .content) return;
        const content = value.content;
        if (content.alternate) |alternate| {
            var alt: std.ArrayListUnmanaged(u8) = .empty;
            for (content.items[alternate..]) |item| if (item.kind == .text) try alt.appendSlice(self.arena, item.text);
            if (alt.items.len == 0) return;
            const index = try self.appendNode(owner, .{ .source = source, .role = .StaticText, .native_role = .StaticText, .has_layout = true, .text = alt.items, .hidden_via_style = hidden });
            _ = index;
            return;
        }
        const pseudo = try self.appendNode(owner, .{
            .source = source,
            .role = .GenericContainer,
            .native_role = .GenericContainer,
            .has_layout = true,
            .hidden_via_style = hidden,
            .ignored = true,
            .reasons = try self.arena.dupe(IgnoredReason, &.{.{ .reason = .uninteresting }}),
        });
        var ordinal: u32 = 0;
        var text: std.ArrayListUnmanaged(u8) = .empty;
        for (content.items) |item| switch (item.kind) {
            .text => try text.appendSlice(self.arena, item.text),
            .quote => {
                if (text.items.len > 0) {
                    try self.appendPseudoText(pseudo, &ordinal, text.items, hidden);
                    text = .empty;
                }
                const glyph = quoteGlyph(item.text, kind) orelse continue;
                const wrapper = try self.appendNode(pseudo, .{
                    .source = .{ .nodeless = ordinal },
                    .role = .GenericContainer,
                    .native_role = .GenericContainer,
                    .has_layout = true,
                    .ignored = true,
                    .reasons = try self.arena.dupe(IgnoredReason, &.{.{ .reason = .uninteresting }}),
                });
                ordinal += 1;
                var inner: u32 = 0;
                try self.appendPseudoText(wrapper, &inner, glyph, hidden);
            },
            else => {},
        };
        if (text.items.len > 0) try self.appendPseudoText(pseudo, &ordinal, text.items, hidden);
    }

    fn appendPseudoText(self: *Tree, owner: Index, ordinal: *u32, text: []const u8, hidden: bool) !void {
        const index = try self.appendNode(owner, .{ .source = .{ .nodeless = ordinal.* }, .role = .StaticText, .native_role = .StaticText, .has_layout = true, .text = text, .hidden_via_style = hidden });
        ordinal.* += 1;
        try self.addInlineTextBoxes(index);
    }

    fn addMarker(self: *Tree, owner: Index, element: *Instance, source: Source, hidden: bool) !void {
        var text: std.ArrayListUnmanaged(u8) = .empty;
        try markerText(self.arena, element, &text);
        const summary = isHtml(element) and eq(localName(element), "summary");
        const presentational = summary or ignoredListItem(element);
        const presentational_reason = try self.arena.dupe(IgnoredReason, &.{.{ .reason = .presentationalRole }});
        const marker = try self.appendNode(owner, .{
            .source = source,
            .role = if (presentational) .None else .ListMarker,
            .native_role = if (presentational) .None else .ListMarker,
            .has_layout = true,
            .hidden_via_style = hidden,
            .ignored = presentational,
            .reasons = if (presentational) presentational_reason else &.{},
            .text = text.items,
        });
        if (text.items.len == 0) return;
        // The marker's text: ignored under a summary's marker and under an
        // unignored one (ComputeIsIgnored's list-marker rule).
        const text_ignored = summary or !presentational;
        const index = try self.appendNode(marker, .{
            .source = .{ .nodeless = 0 },
            .role = .StaticText,
            .native_role = .StaticText,
            .has_layout = true,
            .text = text.items,
            .ignored = text_ignored,
            .reasons = if (text_ignored) presentational_reason else &.{},
            .hidden_via_style = hidden,
        });
        if (!text_ignored) try self.addInlineTextBoxes(index);
    }

    /// Append `node` as the last child of `owner`; its index.
    fn appendNode(self: *Tree, owner: Index, object: Node) !Index {
        const index: Index = @intCast(self.nodes.items.len);
        var copy = object;
        copy.parent = owner;
        try self.nodes.append(self.arena, copy);
        try self.nodes.items[owner].children.append(self.arena, index);
        return index;
    }

    /// The inline text boxes of a StaticText or LineBreak: one per FORCED
    /// line (a preserved newline starts a line box in every engine); soft
    /// wraps need a renderer (main's D1, tmp/plans/a11y1-design.md).
    fn addInlineTextBoxes(self: *Tree, owner: Index) !void {
        const text = self.nodes.items[owner].text;
        if (self.nodes.items[owner].role == .LineBreak) {
            try self.appendBox(owner, 0, "\n");
            return;
        }
        if (text.len == 0) return;
        // Chrome 157 gives a forced break a box of its own: "pre one\npre
        // two" is "pre one", "\n", "pre two" (a11y1-chrome157-trace.txt,
        // page text).
        var ordinal: u32 = 0;
        var start: usize = 0;
        while (std.mem.indexOfScalarPos(u8, text, start, '\n')) |newline| {
            if (newline > start) {
                try self.appendBox(owner, ordinal, text[start..newline]);
                ordinal += 1;
            }
            try self.appendBox(owner, ordinal, text[newline .. newline + 1]);
            ordinal += 1;
            start = newline + 1;
        }
        if (start < text.len) try self.appendBox(owner, ordinal, text[start..]);
    }

    fn appendBox(self: *Tree, owner: Index, ordinal: u32, text: []const u8) !void {
        const index: Index = @intCast(self.nodes.items.len);
        try self.nodes.append(self.arena, .{
            .source = .{ .nodeless = ordinal },
            .parent = owner,
            .role = .InlineTextBox,
            .native_role = .InlineTextBox,
            .has_layout = true,
            .text = text,
        });
        try self.nodes.items[owner].children.append(self.arena, index);
    }

    /// The text a Text renders (LayoutText::PlainText): text-transform
    /// applied, white space collapsed as its parent's white-space says, a
    /// collapsible space dropped at the start and end of a line - at the
    /// block's edges and beside a <br> or a block.
    fn renderedText(self: *Tree, text: *Instance) ![]const u8 {
        var value = try interfaces.CharacterData.get_data(text);
        defer value.deinit(text.ctx.allocator);
        const bytes = try a11y.transformedText(self.arena, text, value.asSlice());
        const p = a11y.parent(text) orelse return bytes;
        if (preservesWhiteSpace(p)) return bytes;
        var out: std.ArrayListUnmanaged(u8) = .empty;
        var in_space = false;
        const keep_newlines = preservesNewlines(p);
        for (bytes) |c| {
            const is_space = std.mem.indexOfScalar(u8, spaces, c) != null;
            if (keep_newlines and c == '\n') {
                // pre-line: spaces before a newline go; the newline stays.
                while (out.items.len > 0 and out.items[out.items.len - 1] == ' ') out.items.len -= 1;
                try out.append(self.arena, '\n');
                in_space = true;
                continue;
            }
            if (is_space) {
                if (!in_space) try out.append(self.arena, ' ');
                in_space = true;
            } else {
                try out.append(self.arena, c);
                in_space = false;
            }
        }
        var result = out.items;
        if (result.len > 0 and (result[0] == ' ' or result[result.len - 1] == ' ')) {
            const edges = try self.lineEdges(text);
            if (result.len > 0 and result[0] == ' ' and edges.start) result = result[1..];
            if (result.len > 0 and result[result.len - 1] == ' ' and edges.end) result = result[0 .. result.len - 1];
        }
        return result;
    }

    /// What a block's lines are made of, in order: its texts, <br>s, atomic
    /// inlines, and the blocks inside it (which end a line).
    const LineItem = union(enum) { text: *Instance, br, atomic, block };

    /// Whether `text` starts and ends a line: nothing inline before (after)
    /// it in its block, a <br> or block next to it, or - before it - text
    /// already ending in white space (whose space the line keeps).
    fn lineEdges(self: *Tree, text: *Instance) !struct { start: bool, end: bool } {
        const block = enclosingBlock(text) orelse return .{ .start = true, .end = true };
        const items = blk: {
            if (self.line_items.get(block)) |cached| break :blk cached;
            var list: std.ArrayListUnmanaged(LineItem) = .empty;
            try collectLineItems(self.arena, bridge.getNodeBase(block).?, &list);
            try self.line_items.put(self.arena, block, list.items);
            break :blk list.items;
        };
        var position: ?usize = null;
        for (items, 0..) |item, i| if (item == .text and item.text == text) {
            position = i;
            break;
        };
        const i = position orelse return .{ .start = true, .end = true };
        const start = if (i == 0) true else switch (items[i - 1]) {
            .br, .block => true,
            .atomic => false,
            .text => |before| endsWithWhitespace(before),
        };
        var j = i + 1;
        while (j < items.len) : (j += 1) {
            if (items[j] == .text and isWhitespaceText(items[j].text)) continue;
            break;
        }
        const end = if (j >= items.len) true else switch (items[j]) {
            .br, .block => true,
            .atomic, .text => false,
        };
        return .{ .start = start, .end = end };
    }

    fn collectLineItems(arena: Allocator, base: *NodeBase, out: *std.ArrayListUnmanaged(LineItem)) Allocator.Error!void {
        // The flat tree's children: a host's shadow root's, a slot's
        // assigned nodes.
        if (a11y.instance(base)) |element| if (base.node_type == NodeBase.ELEMENT_NODE) if (shadows.rootForHost(element)) |shadow| {
            return collectLineItems(arena, bridge.getNodeBase(shadow) orelse return, out);
        };
        if (slots.slotState(base)) |slot| if (slot.hasAssignedNodes()) {
            for (slot.assigned_nodes.items) |ref| if (ref.get()) |assigned| try collectLineItem(arena, assigned, out);
            return;
        };
        var at = base.firstChild();
        while (at) |current| : (at = current.next_sibling) try collectLineItem(arena, current, out);
    }

    fn collectLineItem(arena: Allocator, current: *NodeBase, out: *std.ArrayListUnmanaged(LineItem)) Allocator.Error!void {
        {
            const n = a11y.instance(current) orelse return;
            if (current.node_type == NodeBase.TEXT_NODE or current.node_type == NodeBase.CDATA_SECTION_NODE) {
                var value = interfaces.CharacterData.get_data(n) catch return;
                defer value.deinit(n.ctx.allocator);
                if (value.asSlice().len > 0) try out.append(arena, .{ .text = n });
                return;
            }
            if (current.node_type != NodeBase.ELEMENT_NODE) return;
            if (!(hasBox(n) catch false) and !isDisplayContentsElement(n)) return;
            if (isHtml(n) and eq(localName(n), "br")) {
                try out.append(arena, .br);
            } else if (isDisplayContentsElement(n) or isLayoutInline(n)) {
                try collectLineItems(arena, current, out);
            } else if (isInlineLevel(n)) {
                try out.append(arena, .atomic);
            } else {
                try out.append(arena, .block);
            }
        }
    }
};

// ============================================================================
// What CDP serializes for an object (BuildProtocolAXNodeForAXObject)
// ============================================================================

/// A related node of a property (AXRelatedNode): CDP names it by its
/// backendDOMNodeId and id attribute.
pub const Related = struct { node: *Instance, text: ?[]const u8 = null };

/// An AXValue, by its AXValueType.
pub const Value = union(enum) {
    boolean: bool,
    boolean_or_undefined: bool,
    tristate: []const u8,
    token: []const u8,
    token_list: []const u8,
    string: []const u8,
    integer: i64,
    number: f64,
    /// A boolean whose value Chrome sends as the integer 1: aria-busy
    /// (FillSparseAttributes passes a bool to CreateValue's integer form).
    boolean_one,
    /// `idref`: one related node.
    idref: Related,
    /// `idrefList` (with the attribute's text) and `nodeList`.
    idref_list: struct { attribute_value: ?[]const u8, related: []const Related },
    node_list: []const Related,
};

/// An AXProperty: `name` is CDP's AXPropertyName.
pub const Property = struct { name: []const u8, value: Value };

pub const Description = struct {
    /// The accessible name (null: none sent, for an ignored object).
    name: ?[]const u8 = null,
    /// How the name was found (null: no `sources` sent).
    name_sources: ?[]const NameSource = null,
    description: []const u8 = "",
    value: ?Value = null,
    properties: []const Property = &.{},
};

/// The name, description, value and properties of object `index`
/// (BuildProtocolAXNodeForUnignoredAXObject; an ignored one gets only its
/// name, and only when `force_name` - queryAXTree's force_name_and_role).
pub fn describe(tree: *Tree, index: Index, force_name: bool) !Description {
    const object = tree.node(index);
    if (object.ignored) {
        if (!force_name) return .{};
        return .{ .name = try nameOf(tree, index) };
    }
    var out: Description = .{ .name = try nameOf(tree, index), .name_sources = try nameSources(tree, index) };
    const dom = switch (object.source) {
        .node => |n| n,
        else => {
            out.properties = try nodelessProperties(tree, index);
            return out;
        },
    };
    const node_type = bridge.getNodeBase(dom).?.node_type;
    if (node_type == NodeBase.DOCUMENT_NODE) {
        out.properties = try rootProperties(tree, dom);
        return out;
    }
    if (node_type != NodeBase.ELEMENT_NODE) {
        out.properties = try nodelessProperties(tree, index);
        return out;
    }
    var properties: std.ArrayListUnmanaged(Property) = .empty;
    try properties_(tree, dom, object, nameRelated(out.name_sources orelse &.{}), &properties);
    out.properties = properties.items;
    out.description = try descriptionOf(tree, dom, object, out.name orelse "");
    out.value = try valueOf(tree, dom, object);
    return out;
}

/// The root's: the document is focusable, and its URL (AXNodeObject::Url for
/// the web area). Chrome 157 headless reports no `focused` on the root of a
/// page whose document has no focused element (a11y1-chrome157-trace.txt,
/// every page): AXObjectCacheImpl::FocusedObject falls back to the root only
/// while the page has focus, which a headless page has not.
fn rootProperties(tree: *Tree, document: *Instance) ![]const Property {
    var properties: std.ArrayListUnmanaged(Property) = .empty;
    try properties.append(tree.arena, .{ .name = "focusable", .value = .{ .boolean_or_undefined = true } });
    const url = try interfaces.Document.get_URL(document);
    defer document.ctx.allocator.free(url);
    if (url.len > 0) try properties.append(tree.arena, .{ .name = "url", .value = .{ .string = try tree.arena.dupe(u8, url) } });
    return properties.items;
}

/// Properties of a text or nodeless object: only the global states that
/// apply to them (FillGlobalStates: an editable text's editable state).
fn nodelessProperties(tree: *Tree, index: Index) ![]const Property {
    var properties: std.ArrayListUnmanaged(Property) = .empty;
    // The nearest element ancestor's editability (a text's and an inline
    // box's: Chrome 157 marks both richtext inside a contenteditable).
    var at: ?Index = tree.node(index).parent;
    while (at) |p| : (at = tree.node(p).parent) {
        const n = tree.domNode(p) orelse continue;
        if (bridge.getNodeBase(n).?.node_type != NodeBase.ELEMENT_NODE) continue;
        if (editableKind(n)) |kind| {
            if (eq(kind, "richtext")) try properties.append(tree.arena, .{ .name = "editable", .value = .{ .token = kind } });
        }
        break;
    }
    return properties.items;
}

// ============================================================================
// WebDriver's computed role and label: the same answers
// ============================================================================
//
// chromedriver (Chromium 157.0.8103.78, BSD-3: chrome/test/chromedriver/
// element_util.cc GetAXNodeByElementId, element_commands.cc
// ExecuteGetComputedRole / ExecuteGetComputedLabel) answers WebDriver's Get
// Computed Role and Get Computed Label off the Accessibility domain's
// getPartialAXTree {backendNodeId, fetchRelatives: false} node for the
// element: its role.value, and its name.value ("" when it has none). Crane
// answers both from that one decision - the tree's - in Chrome's
// vocabulary, except where golden rule 2 says the browser majority answers
// otherwise (`webdriverOverride`, each with its evidence).

/// WebDriver's answers for one element.
pub const WebDriverAnswer = struct { role: []const u8, label: []const u8 };

/// The getPartialAXTree node's role for `element` in its node document's
/// tree (BuildProtocolAXNodeForDOMNodeWithNoAXNode, and an ignored object:
/// role none), and its accessible name, with the rule-2 overrides. Strings
/// live in `arena` or are static.
pub fn webdriverAnswer(arena: Allocator, element: *Instance, options: Options) !WebDriverAnswer {
    // The label: chromedriver sends the CDP node's name, none for an ignored
    // object or an element with no object, where Firefox and Safari compute
    // AccName all the same (a <b>'s or a <wbr>'s title, a <video>'s
    // aria-label: html-aam/accname-computation-by-element/
    // phrasing-elements.html and section-and-grouping-elements.html, wpt.fyi
    // Chrome 157 4786307730243584 fails, Firefox 160 4877168468033536 and
    // Safari 27.2 6479119966273536 pass) - the majority's answer, for every
    // element: AccName, roles by its own decision, in the tree the element's
    // root roots (a detached subtree too).
    const label = try a11y.computedName(arena, element, options.names());
    // Detached: no document's tree holds it, and chromedriver would refuse
    // it as stale. Crane answers the element's own role (the harness choice
    // crane/ar3-pending-command-gc.html pins: WPT's selector transport sends
    // :scope for an id-less detached element, and Chrome, Firefox and Safari
    // pass aria-element-reflection-labelledby.html through that artifact).
    if (!(interfaces.Node.get_isConnected(element) catch false)) {
        return .{ .role = try a11y.role(arena, element, options.names()), .label = label };
    }
    const document = if (element.implements(interfaces.Document.State)) element else (interfaces.Node.get_ownerDocument(element) catch null) orelse return .{ .role = "none", .label = label };
    const tree = try arena.create(Tree);
    tree.* = try Tree.build(arena, document, options);
    const index = tree.indexOf(element) orelse return .{ .role = "none", .label = label };
    const object = tree.node(index);
    if (object.ignored) return .{ .role = "none", .label = label };
    return .{ .role = object.role.cdpName().name, .label = label };
}

/// The accessible name CDP sends.
pub fn nameOf(tree: *Tree, index: Index) ![]const u8 {
    const object = tree.node(index);
    switch (object.role) {
        .StaticText, .InlineTextBox => return object.text,
        .LineBreak => return "\n",
        else => {},
    }
    switch (object.source) {
        .node => |dom| {
            const base = bridge.getNodeBase(dom).?;
            if (base.node_type == NodeBase.DOCUMENT_NODE) {
                var title = try interfaces.Document.get_title(dom);
                defer title.deinit(dom.ctx.allocator);
                return tree.arena.dupe(u8, title.asSlice());
            }
            if (base.node_type != NodeBase.ELEMENT_NODE) return object.text;
            return tree.names.nameWithContents(dom, nameFromContents(tree, dom, object.role), try tree.names.hidden(dom));
        },
        .pseudo, .nodeless => return object.text,
    }
}

/// SupportsNameFromContents for the object's Chromium role: a row only in
/// a grid or treegrid.
fn nameFromContents(tree: *Tree, dom: *Instance, role: Role) bool {
    if (role == .Row) {
        const table = tree.tableAncestorRole(dom) orelse return false;
        return table == .Grid or table == .TreeGrid;
    }
    return supportsNameFromContents(role);
}

// ============================================================================
// The name's sources (Blink AXObject::NameSources, CDP's AXValueSource list)
// ============================================================================
//
// GetName(name_sources) runs TextAlternative to the end, recording each
// place a name can come from in the order it looks, whether or not an
// earlier one gave the name (Chromium 157.0.8103.78, BSD-3:
// third_party/blink/renderer/modules/accessibility/ax_node_object.cc
// TextAlternative, NativeTextAlternative, TextAlternativeFromTooltip,
// TextAlternativeFromTitleAttribute; ax_object.cc AriaTextAlternative,
// TextFromElements; inspector_type_builder_helper.cc CreateValueSource).
// The name itself stays dom/accessibility.zig's computation: each source's
// text comes from that computation's own steps (Names.labelledbyTexts,
// labelTexts, contentsText, nativeLabelText), so the sources show how the
// one name was found.

/// AXValueSourceType (ValueSourceType: a NameFrom of an attribute, an
/// explicitly empty one, a title or a value is "attribute", a caption or a
/// related element "relatedElement", CSS alt text "implicit").
pub const SourceType = enum { attribute, implicit, contents, placeholder, relatedElement };

/// AXValueNativeSourceType (NativeSourceType).
pub const NativeSource = enum { label, labelfor, labelwrapped, legend, tablecaption, title };

/// One NameSource, as CreateValueSource sends it.
pub const NameSource = struct {
    type: SourceType,
    /// The attribute it reads (`attribute`).
    attribute: ?[]const u8 = null,
    /// That attribute's value (`attributeValue`: a string, or for
    /// aria-labelledby with related elements an idrefList carrying it).
    attribute_value: ?[]const u8 = null,
    /// The text it gave (`value`, a computedString), when it gave one.
    text: ?[]const u8 = null,
    /// A source before it gave the name (NameSource(found_text_alternative)).
    superseded: bool = false,
    invalid: bool = false,
    native_source: ?NativeSource = null,
    /// The elements whose text it is, each with that text (aria-labelledby's
    /// idrefList, a native source's nodeList).
    related: []const Related = &.{},
};

/// The sources list as TextAlternative fills it: `found` is its
/// found_text_alternative, which marks every later source superseded.
const Sources = struct {
    arena: Allocator,
    items: std.ArrayListUnmanaged(NameSource) = .empty,
    found: bool = false,

    /// Appends `source`, superseded when an earlier one gave the name; it
    /// gives the name itself when it has a text (`gives`, else as told).
    fn add(self: *Sources, source: NameSource) !void {
        try self.addGiving(source, source.text != null);
    }

    fn addGiving(self: *Sources, source: NameSource, gives: bool) !void {
        var entry = source;
        entry.superseded = self.found;
        try self.items.append(self.arena, entry);
        if (gives) self.found = true;
    }
};

/// The name sources CDP sends for object `index` (null: none, as for an
/// InlineTextBox, whose AXInlineTextBox names itself without them, and an
/// ignored object).
pub fn nameSources(tree: *Tree, index: Index) !?[]const NameSource {
    const object = tree.node(index);
    if (object.ignored) return null;
    var list: Sources = .{ .arena = tree.arena };
    switch (object.role) {
        .InlineTextBox => return null,
        // A layout text's own text; a pseudo-element's alternative text
        // (GetCSSAltText: NameFrom kCssAltText, sent as implicit).
        .StaticText => {
            try list.add(.{ .type = if (object.source == .pseudo) .implicit else .contents, .text = object.text });
            return list.items.items;
        },
        // A list marker's text alternative; a <br>'s "\n".
        .ListMarker => {
            try list.add(.{ .type = .contents, .text = object.text });
            return list.items.items;
        },
        .LineBreak => {
            try list.add(.{ .type = .contents, .text = "\n" });
            return list.items.items;
        },
        else => {},
    }
    const dom = switch (object.source) {
        .node => |n| n,
        // The select's pop-up: Chrome's is its user-agent picker element,
        // with no attributes of its own (a11y1-chrome157-trace.txt, the
        // forms page): aria-labelledby, aria-label, then its title.
        .pseudo, .nodeless => {
            try list.add(.{ .type = .relatedElement, .attribute = "aria-labelledby" });
            try list.add(.{ .type = .attribute, .attribute = "aria-label" });
            try list.add(.{ .type = .attribute, .attribute = "title" });
            return list.items.items;
        },
    };
    const node_type = bridge.getNodeBase(dom).?.node_type;
    if (node_type == NodeBase.DOCUMENT_NODE) {
        try documentSources(tree, dom, &list);
        return list.items.items;
    }
    if (node_type != NodeBase.ELEMENT_NODE) return null;
    const hidden = object.hidden_via_style or ariaHiddenRoot(tree, dom);
    // AriaTextAlternative. A slot names nothing; 2A: a node hidden from the
    // text alternative (an aria-hidden root, or hidden by its style) is
    // found with no text, so every later source is superseded.
    if (isHtml(dom) and eq(localName(dom), "slot")) {} else if (hidden) {
        list.found = true;
    } else {
        try ariaSources(tree, dom, &list);
    }
    // 2D: the host language's.
    const explicitly_empty = try nativeSources(tree, dom, object, &list);
    // 2F: the contents, where the role takes a name from them (not a
    // select's options, not a text field's value; not a menu list option
    // with one text child, whose DisplayLabel was its contents source:
    // SupportsNameFromContents).
    const one_text_option = object.role == .MenuListOption and hasOneTextChild(dom);
    if (nameFromContents(tree, dom, object.role) and !one_text_option and !isTextField(dom, object) and !(isHtml(dom) and eq(localName(dom), "select"))) {
        const text = try contentsOf(tree, dom, hidden);
        try list.add(.{ .type = .contents, .text = if (text.len > 0) text else null });
    }
    // 2I: the tooltip, unless the role prohibits a name, or an image's alt
    // is explicitly empty.
    if (!nameProhibited(tree, dom, object) and !explicitly_empty) try tooltipSource(dom, &list);
    return list.items.items;
}

/// AriaTextAlternative 2B (aria-labelledby, or aria-labeledby when only
/// that spelling is set) and 2C (aria-label).
fn ariaSources(tree: *Tree, dom: *Instance, list: *Sources) !void {
    const legacy = attribute(dom, "aria-labeledby") != null and attribute(dom, "aria-labelledby") == null;
    var labelledby: NameSource = .{ .type = .relatedElement, .attribute = if (legacy) "aria-labeledby" else "aria-labelledby" };
    if (attribute(dom, labelledby.attribute.?)) |value| {
        labelledby.attribute_value = value;
        const texts = try tree.names.labelledbyTexts(dom);
        const joined = try joinTexts(tree.arena, texts);
        if (std.mem.trim(u8, joined, spaces).len > 0) {
            labelledby.text = joined;
            labelledby.related = try relatedOf(tree.arena, texts);
        } else labelledby.invalid = true;
    }
    try list.add(labelledby);
    var label: NameSource = .{ .type = .attribute, .attribute = "aria-label" };
    if (try a11y.effective(tree.arena, dom, "aria-label", "ariaLabel")) |value| if (std.mem.trim(u8, value, spaces).len > 0) {
        label.text = value;
        label.attribute_value = value;
    };
    try list.add(label);
}

/// NativeTextAlternative's sources for an element. Returns whether an
/// image's (or area's) alt is explicitly empty (kAttributeExplicitlyEmpty,
/// which keeps the tooltip out).
fn nativeSources(tree: *Tree, dom: *Instance, object: *const Node, list: *Sources) !bool {
    if (!isHtml(dom)) {
        try svgSources(tree, dom, list);
        return false;
    }
    const tag = localName(dom);
    // An option with one text child: HTMLOptionElement::DisplayLabel.
    if (eq(tag, "option") and hasOneTextChild(dom)) {
        var label = try interfaces.HTMLOptionElement.get_label(dom);
        defer label.deinit(dom.ctx.allocator);
        if (label.asSlice().len > 0) {
            try list.add(.{ .type = .contents, .text = try tree.arena.dupe(u8, label.asSlice()) });
            return false;
        }
    }
    // An optgroup's label (GroupLabelText), a source with no attribute.
    if (eq(tag, "optgroup")) {
        const label = try collapse(tree.arena, attribute(dom, "label") orelse "");
        if (label.len > 0) {
            try list.add(.{ .type = .attribute, .text = label });
            return false;
        }
    }
    // 5.1/5.5: a labelable element's labels.
    if (try tree.names.labelTexts(dom)) |labels| {
        var source: NameSource = .{ .type = .relatedElement, .native_source = .label };
        var gives = false;
        if (labels.len > 0) {
            const id = attribute(dom, "id") orelse "";
            for (labels) |l| {
                const target = attribute(l.node, "for") orelse "";
                source.native_source = if (target.len > 0 and eq(target, id)) .labelfor else .labelwrapped;
            }
            source.text = std.mem.trim(u8, try joinTexts(tree.arena, labels), spaces);
            source.related = try relatedOf(tree.arena, labels);
            gives = true;
        }
        try list.addGiving(source, gives);
    }
    if (eq(tag, "input")) {
        var kind_value = try interfaces.HTMLInputElement.get_type(dom);
        defer kind_value.deinit(dom.ctx.allocator);
        const kind = kind_value.asSlice();
        // 5.2: a text button's value attribute; its default label when it
        // is not laid out.
        if (oneOf(kind, .{ "button", "submit", "reset" })) {
            const value = attribute(dom, "value");
            try list.add(.{ .type = .attribute, .attribute = "value", .text = value });
            if (value == null and !object.has_layout) if (defaultButtonLabel(kind)) |label| try list.add(.{ .type = .contents, .text = label });
            return false;
        }
        // 5.3: an image button's alt, value, tooltip and its localized
        // "Submit" (IDS_FORM_SUBMIT_LABEL), the last always giving a name.
        if (eq(kind, "image")) {
            const alt = attribute(dom, "alt");
            var alt_source: NameSource = .{ .type = .attribute, .attribute = "alt" };
            if (alt) |a| if (a.len > 0) {
                alt_source.text = a;
                alt_source.attribute_value = a;
            };
            try list.add(alt_source);
            try list.add(.{ .type = .attribute, .attribute = "value", .text = attribute(dom, "value") });
            try tooltipSource(dom, list);
            try list.add(.{ .type = .attribute, .attribute = "type", .attribute_value = attribute(dom, "type"), .text = @import("control_labels.zig").submit });
            return false;
        }
        // A file chooser: its button's label, as the contents.
        if (eq(kind, "file")) try list.add(.{ .type = .contents, .attribute = "value", .text = @import("control_labels.zig").choose_file });
    }
    // 5.1 step 3: a text control's tooltip, then its placeholder.
    if (isTextControl(dom)) {
        try tooltipSource(dom, list);
        var placeholder: NameSource = .{ .type = .placeholder, .attribute = "placeholder" };
        if (attribute(dom, "placeholder")) |value| if (value.len > 0) {
            placeholder.text = value;
            placeholder.attribute_value = value;
        };
        try list.add(placeholder);
    }
    // And a text field's aria-placeholder.
    if (isTextField(dom, object)) {
        var placeholder: NameSource = .{ .type = .placeholder, .attribute = "aria-placeholder" };
        if (try a11y.effective(tree.arena, dom, "aria-placeholder", "ariaPlaceholder")) |value| if (value.len > 0) {
            placeholder.text = value;
            placeholder.attribute_value = value;
        };
        try list.add(placeholder);
        return false;
    }
    // 5.8: an img's or area's alt.
    if (oneOf(tag, .{ "img", "area" })) {
        const alt = attribute(dom, "alt");
        try list.add(.{ .type = .attribute, .attribute = "alt", .attribute_value = alt, .text = alt });
        return alt != null and alt.?.len == 0;
    }
    // 5.9: a table's first caption not hidden, then its summary.
    if (eq(tag, "table")) {
        var source: NameSource = .{ .type = .relatedElement, .native_source = .tablecaption };
        if (try firstUnhiddenChild(tree, dom, "caption")) |caption| {
            const text = try tree.names.nativeLabelText(dom, caption);
            source.text = text;
            source.related = try tree.arena.dupe(Related, &.{.{ .node = caption, .text = try collapseRuns(tree.arena, text) }});
        }
        try list.add(source);
        const summary = attribute(dom, "summary");
        try list.add(.{ .type = .attribute, .attribute = "summary", .attribute_value = summary, .text = summary });
        return false;
    }
    // A fieldset's legend (HTMLFieldSetElement::Legend: its first legend
    // child).
    if (eq(tag, "fieldset")) {
        var source: NameSource = .{ .type = .relatedElement, .native_source = .legend };
        var gives = false;
        if (a11y.firstChildNamed(dom, "legend")) |legend| {
            const text = try tree.names.nativeLabelText(dom, legend);
            source.text = text;
            source.related = try tree.arena.dupe(Related, &.{.{ .node = legend, .text = try collapseRuns(tree.arena, text) }});
            gives = true;
        }
        try list.addGiving(source, gives);
    }
    return false;
}

/// SVG-AAM's 2D: the first <title> child's text, and an SVG link's
/// xlink:title.
fn svgSources(tree: *Tree, dom: *Instance, list: *Sources) !void {
    if (!isSvg(dom)) return;
    var title_source: NameSource = .{ .type = .relatedElement, .native_source = .title };
    if (a11y.firstChildNamed(dom, "title")) |title| {
        // GetInnerTextWithoutUpdate: an SVG element's is its text content.
        if (try interfaces.Node.get_textContent(title)) |text_value| {
            var text = text_value;
            defer text.deinit(title.ctx.allocator);
            if (text.asSlice().len > 0) title_source.text = try tree.arena.dupe(u8, text.asSlice());
        }
    }
    try list.add(title_source);
    if (eq(localName(dom), "a")) {
        // CreateValueSource sends the attribute's local name.
        var link: NameSource = .{ .type = .attribute, .attribute = "title" };
        const xlink_title = if (data.of(dom)) |element| element.findAttribute("http://www.w3.org/1999/xlink", "title") else null;
        if (xlink_title) |entry| if (entry.value.len > 0) {
            const value = entry.value;
            link.text = value;
            link.attribute_value = value;
        };
        try list.add(link);
    }
}

/// The web area's: AriaTextAlternative's two (the document has no
/// attributes), then the document's: its element's aria-label and its title.
fn documentSources(tree: *Tree, document: *Instance, list: *Sources) !void {
    try list.add(.{ .type = .relatedElement, .attribute = "aria-labelledby" });
    try list.add(.{ .type = .attribute, .attribute = "aria-label" });
    var label: NameSource = .{ .type = .attribute, .attribute = "aria-label" };
    if (try interfaces.Document.get_documentElement(document)) |root| {
        if (try a11y.effective(tree.arena, root, "aria-label", "ariaLabel")) |value| if (value.len > 0) {
            label.text = value;
            label.attribute_value = value;
        };
    }
    try list.add(label);
    // Blink builds this one from the pointer `found_text_alternative`, not
    // the flag it points at, so it is always superseded (Chrome 157: every
    // RootWebArea of a11y1-chrome157-trace.txt).
    list.items.items[list.items.items.len - 1].superseded = true;
    var title = try interfaces.Document.get_title(document);
    defer title.deinit(document.ctx.allocator);
    try list.addGiving(.{ .type = .relatedElement, .native_source = .title, .text = try tree.arena.dupe(u8, title.asSlice()) }, true);
}

/// TextAlternativeFromTooltip's title source: the title attribute, unless
/// it only repeats the element's inner text. (Its interestfor and hint
/// popover sources follow: TODO(a11y1), no page of the trace has one.)
fn tooltipSource(dom: *Instance, list: *Sources) !void {
    var source: NameSource = .{ .type = .attribute, .attribute = "title" };
    if (attribute(dom, "title")) |title| {
        const own = std.mem.trim(u8, title, spaces);
        var inner: []const u8 = "";
        var inner_text: ?runtime.DOMString = null;
        defer if (inner_text) |*t| t.deinit(dom.ctx.allocator);
        if (dom.stateAs(interfaces.HTMLElement.State) != null) {
            inner_text = try interfaces.HTMLElement.get_innerText(dom);
            inner = std.mem.trim(u8, inner_text.?.asSlice(), spaces);
        }
        if (!eq(own, inner)) {
            source.text = title;
            source.attribute_value = title;
        }
    }
    try list.add(source);
}

/// The text 2F's contents source shows: a control's user-agent contents
/// (a text button's label, an image button's alt), else the element's.
fn contentsOf(tree: *Tree, dom: *Instance, hidden: bool) ![]const u8 {
    if (isHtml(dom) and eq(localName(dom), "input")) {
        var kind_value = try interfaces.HTMLInputElement.get_type(dom);
        defer kind_value.deinit(dom.ctx.allocator);
        const kind = kind_value.asSlice();
        if (oneOf(kind, .{ "button", "submit", "reset" })) return attribute(dom, "value") orelse defaultButtonLabel(kind) orelse "";
        if (eq(kind, "image")) return attribute(dom, "alt") orelse "";
        return "";
    }
    return tree.names.contentsText(dom, hidden);
}

fn defaultButtonLabel(kind: []const u8) ?[]const u8 {
    if (eq(kind, "submit")) return @import("control_labels.zig").submit;
    if (eq(kind, "reset")) return @import("control_labels.zig").reset;
    return null;
}

/// AXObject::IsNameProhibited: a role whose name ARIA prohibits, unless the
/// object is focusable or a custom element. It reads RoleValue(), the role
/// before ComputeFinalRoleForSerialization: an unnamed <section> (sent as
/// SectionWithoutName) and an <aside> inside an article (sent as generic)
/// still show their title source (Chrome 157, the trace's structure page).
fn nameProhibited(tree: *Tree, dom: *Instance, object: *const Node) bool {
    if (focusable(tree, dom, object.role)) return false;
    if (isCustomElement(dom)) return false;
    return roleIsNameProhibited(if (object.aria_role != .Unknown) object.aria_role else object.native_role);
}

/// RoleIsNameProhibited (ax_utilities_generated_naming.cc.tmpl): the roles
/// whose aria_properties.json5 nameFrom is ["prohibited"], by their
/// internal roles.
fn roleIsNameProhibited(role: Role) bool {
    return switch (role) {
        .Caption, .Code, .Definition, .ContentDeletion, .Emphasis, .GenericContainer, .SectionWithoutName, .ContentInsertion, .Mark, .None, .Paragraph, .Strong, .Subscript, .Suggestion, .Superscript, .Term, .Time => true,
        else => false,
    };
}

/// AXObject::IsTextField: a native text control, or else an element with a
/// contenteditable attribute or an ARIA text field role (RawAriaRole:
/// textbox, searchbox, a text combobox).
fn isTextField(dom: *Instance, object: *const Node) bool {
    if (isTextControl(dom)) return true;
    if (attribute(dom, "contenteditable")) |value| if (!std.ascii.eqlIgnoreCase(value, "false")) return true;
    return object.aria_role == .TextField or object.aria_role == .SearchBox or object.aria_role == .TextFieldWithComboBox;
}

/// Element::IsTextControl: a textarea, or an input whose type is a text
/// field's.
fn isTextControl(dom: *Instance) bool {
    if (!isHtml(dom)) return false;
    if (eq(localName(dom), "textarea")) return true;
    if (!eq(localName(dom), "input")) return false;
    var kind = interfaces.HTMLInputElement.get_type(dom) catch return false;
    defer kind.deinit(dom.ctx.allocator);
    return oneOf(kind.asSlice(), .{ "text", "search", "url", "tel", "email", "password", "number" });
}

/// IsAriaHiddenRoot: the element's own aria-hidden is true.
fn ariaHiddenRoot(tree: *Tree, dom: *Instance) bool {
    const value = (a11y.effective(tree.arena, dom, "aria-hidden", "ariaHidden") catch return false) orelse return false;
    return std.ascii.eqlIgnoreCase(std.mem.trim(u8, value, spaces), "true");
}

/// HTMLOptionElement::HasOneTextChild.
fn hasOneTextChild(dom: *Instance) bool {
    const base = bridge.getNodeBase(dom).?;
    const first = base.firstChild() orelse return false;
    return first.next_sibling == null and first.node_type == NodeBase.TEXT_NODE;
}

/// The first child element named `name` not hidden from the accessibility
/// tree (FirstUnhiddenTableCaption).
fn firstUnhiddenChild(tree: *Tree, dom: *Instance, name: []const u8) !?*Instance {
    const base = bridge.getNodeBase(dom).?;
    var at = base.firstChild();
    while (at) |child| : (at = child.next_sibling) {
        const element = a11y.instance(child) orelse continue;
        if (child.node_type != NodeBase.ELEMENT_NODE or !eq(localName(element), name)) continue;
        if (!try tree.names.hidden(element)) return element;
    }
    return null;
}

/// TextFromElements' accumulated text: the non-empty texts, one space
/// between.
fn joinTexts(arena: Allocator, texts: []const a11y.RelatedText) ![]const u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    for (texts) |t| {
        if (t.text.len == 0) continue;
        if (out.items.len > 0) try out.append(arena, ' ');
        try out.appendSlice(arena, t.text);
    }
    return out.items;
}

/// The related objects, each text with its runs of white space made one
/// (as Chrome 157 sends them, a11y1-chrome157-trace.txt).
fn relatedOf(arena: Allocator, texts: []const a11y.RelatedText) ![]const Related {
    var out: std.ArrayListUnmanaged(Related) = .empty;
    for (texts) |t| try out.append(arena, .{ .node = t.node, .text = try collapseRuns(arena, t.text) });
    return out.items;
}

/// The labelledby property's related objects: those of each source that
/// gave a text and is not superseded (BuildProtocolAXNodeForUnignoredAXObject).
fn nameRelated(sources: []const NameSource) []const Related {
    for (sources) |source| {
        if (source.text == null or source.superseded) continue;
        if (source.related.len > 0) return source.related;
    }
    return &.{};
}

/// AXNodeObject::Description (CDP sends no sources for it): describedby,
/// aria-description, a text button's value, a table's caption, a summary's
/// text, the title attribute.
fn descriptionOf(tree: *Tree, dom: *Instance, object: *const Node, name: []const u8) ![]const u8 {
    _ = object;
    if (attribute(dom, "aria-describedby") != null) {
        var out: std.ArrayListUnmanaged(u8) = .empty;
        var tokens = std.mem.tokenizeAny(u8, attribute(dom, "aria-describedby").?, spaces);
        while (tokens.next()) |id| {
            const target = @import("element_references.zig").byId(dom, id) orelse continue;
            const text = try tree.names.nameOfRelation(target);
            if (text.len == 0) continue;
            if (out.items.len > 0) try out.append(tree.arena, ' ');
            try out.appendSlice(tree.arena, text);
        }
        if (out.items.len > 0) return collapse(tree.arena, out.items);
    }
    if (try a11y.effective(tree.arena, dom, "aria-description", "ariaDescription")) |value| return collapse(tree.arena, value);
    if (attribute(dom, "title")) |title| {
        const trimmed = std.mem.trim(u8, title, spaces);
        if (trimmed.len > 0 and !eq(trimmed, name)) return collapse(tree.arena, title);
    }
    return "";
}

/// Runs of white space made one space, none trimmed.
fn collapseRuns(arena: Allocator, text: []const u8) ![]const u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var in_space = false;
    for (text) |c| {
        if (std.mem.indexOfScalar(u8, spaces, c) != null) {
            if (!in_space) try out.append(arena, ' ');
            in_space = true;
        } else {
            try out.append(arena, c);
            in_space = false;
        }
    }
    return out.items;
}

fn collapse(arena: Allocator, text: []const u8) ![]const u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var pending = false;
    for (text) |c| {
        if (std.mem.indexOfScalar(u8, spaces, c) != null) {
            pending = out.items.len > 0;
        } else {
            if (pending) try out.append(arena, ' ');
            pending = false;
            try out.append(arena, c);
        }
    }
    return out.items;
}

/// FillCoreProperties' value: a range's number, else the control's value.
fn valueOf(tree: *Tree, dom: *Instance, object: *const Node) !?Value {
    if (rangeSupported(tree, dom, object.role)) {
        if (try rangeValue(tree, dom, object.role, .now)) |n| return .{ .number = n };
        return null;
    }
    const text = try controlValue(tree, dom, object) orelse return null;
    if (text.len == 0) return null;
    return .{ .string = text };
}

/// SlowGetValueForControlIncludingContentEditable.
fn controlValue(tree: *Tree, dom: *Instance, object: *const Node) !?[]const u8 {
    if (dom.stateAs(interfaces.HTMLInputElement.State) != null) {
        var kind = try interfaces.HTMLInputElement.get_type(dom);
        defer kind.deinit(dom.ctx.allocator);
        if (eq(kind.asSlice(), "file")) {
            // The file chooser's text (HTML-AAM: a button; Chrome 157 sends
            // "No file chosen" as its value, a11y1-chrome157-trace.txt).
            const files = try interfaces.HTMLInputElement.get_files(dom);
            if (files == null or try interfaces.FileList.get_length(files.?) == 0) return @import("control_labels.zig").no_file;
            const file = (try interfaces.FileList.call_item(files.?, 0)) orelse return null;
            var name = try interfaces.File.get_name(file);
            defer name.deinit(file.ctx.allocator);
            return try tree.arena.dupe(u8, name.asSlice());
        }
        if (oneOf(kind.asSlice(), .{ "checkbox", "radio", "button", "submit", "reset", "image", "hidden" })) return null;
        var value = try interfaces.HTMLInputElement.get_value(dom);
        defer value.deinit(dom.ctx.allocator);
        if (eq(kind.asSlice(), "password")) {
            // A password's characters are not exposed: one bullet each.
            var out: std.ArrayListUnmanaged(u8) = .empty;
            const view = std.unicode.Wtf8View.init(value.asSlice()) catch return null;
            var it = view.iterator();
            while (it.nextCodepoint()) |_| try out.appendSlice(tree.arena, "\u{2022}");
            return out.items;
        }
        return try tree.arena.dupe(u8, value.asSlice());
    }
    if (dom.stateAs(interfaces.HTMLTextAreaElement.State) != null) {
        var value = try interfaces.HTMLTextAreaElement.get_value(dom);
        defer value.deinit(dom.ctx.allocator);
        return try tree.arena.dupe(u8, value.asSlice());
    }
    if (dom.stateAs(interfaces.HTMLSelectElement.State) != null) {
        if (object.native_role != .ComboBoxSelect) return null;
        // The selected option's label (HTMLOptionElement::DisplayLabel).
        const option = try selectedOption(dom) orelse return null;
        var text = try interfaces.HTMLOptionElement.get_label(option);
        defer text.deinit(option.ctx.allocator);
        return try tree.arena.dupe(u8, text.asSlice());
    }
    if (editableKind(dom) != null and isEditableRoot(dom)) {
        var text = try interfaces.HTMLElement.get_innerText(dom);
        defer text.deinit(dom.ctx.allocator);
        return try tree.arena.dupe(u8, text.asSlice());
    }
    return null;
}

/// A select's first selected option, among its children and its
/// optgroups' (the select's list of options).
fn selectedOption(select: *Instance) !?*Instance {
    const base = bridge.getNodeBase(select).?;
    var at = base.firstChild();
    while (at) |current| : (at = current.next_sibling) {
        const n = a11y.instance(current) orelse continue;
        if (n.stateAs(interfaces.HTMLOptionElement.State) != null) {
            if (try interfaces.HTMLOptionElement.get_selected(n)) return n;
        } else if (isHtml(n) and eq(localName(n), "optgroup")) {
            var inner = current.firstChild();
            while (inner) |o| : (inner = o.next_sibling) {
                const option = a11y.instance(o) orelse continue;
                if (option.stateAs(interfaces.HTMLOptionElement.State) == null) continue;
                if (try interfaces.HTMLOptionElement.get_selected(option)) return option;
            }
        }
    }
    return null;
}

const RangeValue = enum { now, min, max };

/// A range role's value, minimum or maximum: ARIA's, else the native
/// control's, else the role's default (AXNodeObject::ValueForRange,
/// MinValueForRange, MaxValueForRange).
fn rangeValue(tree: *Tree, dom: *Instance, role: Role, which: RangeValue) !?f64 {
    _ = tree;
    const aria = switch (which) {
        .now => "aria-valuenow",
        .min => "aria-valuemin",
        .max => "aria-valuemax",
    };
    if (attribute(dom, aria)) |text| {
        if (std.fmt.parseFloat(f64, std.mem.trim(u8, text, spaces))) |n| return n else |_| {}
    }
    if (dom.stateAs(interfaces.HTMLInputElement.State) != null) {
        return switch (which) {
            .now => blk: {
                const n = try interfaces.HTMLInputElement.get_valueAsNumber(dom);
                break :blk if (std.math.isNan(n)) null else n;
            },
            .min => numberAttribute(dom, "min") orelse (if (role == .Slider) 0 else null),
            .max => numberAttribute(dom, "max") orelse (if (role == .Slider) 100 else null),
        };
    }
    if (dom.stateAs(interfaces.HTMLProgressElement.State) != null) return switch (which) {
        .now => if (attribute(dom, "value") != null) try interfaces.HTMLProgressElement.get_value(dom) else null,
        .min => 0,
        .max => try interfaces.HTMLProgressElement.get_max(dom),
    };
    if (dom.stateAs(interfaces.HTMLMeterElement.State) != null) return switch (which) {
        .now => try interfaces.HTMLMeterElement.get_value(dom),
        .min => try interfaces.HTMLMeterElement.get_min(dom),
        .max => try interfaces.HTMLMeterElement.get_max(dom),
    };
    // ARIA's defaults for sliders, scrollbars and separators.
    return switch (which) {
        .now => if (role == .Slider or role == .ScrollBar) 50 else null,
        .min => if (role == .SpinButton) null else 0,
        .max => if (role == .SpinButton) null else 100,
    };
}

fn numberAttribute(dom: *Instance, name: []const u8) ?f64 {
    const text = attribute(dom, name) orelse return null;
    return std.fmt.parseFloat(f64, std.mem.trim(u8, text, spaces)) catch null;
}

/// IsRangeValueSupported: a separator only when it is focusable (a
/// splitter widget).
fn rangeSupported(tree: *Tree, dom: *Instance, role: Role) bool {
    return switch (role) {
        .Slider, .SpinButton, .ScrollBar, .ProgressIndicator, .Meter => true,
        .Splitter => tree.options.is_focusable(dom),
        else => false,
    };
}

fn nativeValueText(tree: *Tree, dom: *Instance) ![]const u8 {
    if (dom.stateAs(interfaces.HTMLInputElement.State) == null) return "";
    var value = try interfaces.HTMLInputElement.get_value(dom);
    defer value.deinit(dom.ctx.allocator);
    return tree.arena.dupe(u8, value.asSlice());
}

/// "plaintext" or "richtext" for an editable object (kEditable).
fn editableKind(dom: *Instance) ?[]const u8 {
    if (dom.stateAs(interfaces.HTMLInputElement.State) != null or dom.stateAs(interfaces.HTMLTextAreaElement.State) != null) {
        // Disabled and read-only fields stay editable (kEditable); only
        // settable goes (Chrome 157: the trace's "Off" and "RO" fields).
        if (dom.stateAs(interfaces.HTMLInputElement.State) != null) {
            var kind = interfaces.HTMLInputElement.get_type(dom) catch return null;
            defer kind.deinit(dom.ctx.allocator);
            if (!oneOf(kind.asSlice(), .{ "text", "search", "email", "url", "tel", "password", "number" })) return null;
        }
        return "plaintext";
    }
    if (dom.stateAs(interfaces.HTMLElement.State) != null) {
        if (interfaces.HTMLElement.get_isContentEditable(dom) catch false) {
            return if (attribute(dom, "contenteditable")) |v| (if (std.ascii.eqlIgnoreCase(v, "plaintext-only")) "plaintext" else "richtext") else "richtext";
        }
    }
    return null;
}

/// FillLiveRegionProperties, FillGlobalStates, FillWidgetProperties,
/// FillWidgetStates, FillRelationships, FillSparseAttributes, and the
/// labelledby of the name's sources, in Blink's order.
fn properties_(tree: *Tree, dom: *Instance, object: *const Node, name_related: []const Related, out: *std.ArrayListUnmanaged(Property)) !void {
    const arena = tree.arena;
    const role = object.role;
    // FillLiveRegionProperties: an active live region root.
    if (liveStatus(dom, role)) |live| if (!eq(live, "off")) {
        try out.append(arena, .{ .name = "live", .value = .{ .token = live } });
        // ARIA's implicit aria-atomic: true for alert and status.
        const atomic = if (attribute(dom, "aria-atomic")) |v| std.ascii.eqlIgnoreCase(v, "true") else (role == .Alert or role == .Status);
        try out.append(arena, .{ .name = "atomic", .value = .{ .boolean = atomic } });
        try out.append(arena, .{ .name = "relevant", .value = .{ .token_list = attribute(dom, "aria-relevant") orelse "additions text" } });
    };
    // FillGlobalStates.
    if (tree.options.is_disabled(dom) or ariaDisabled(dom)) try out.append(arena, .{ .name = "disabled", .value = .{ .boolean = true } });
    if (invalidState(tree, dom)) |invalid| try out.append(arena, .{ .name = "invalid", .value = .{ .token = invalid } });
    if (focusable(tree, dom, role)) try out.append(arena, .{ .name = "focusable", .value = .{ .boolean_or_undefined = true } });
    if (isFocused(tree, dom)) try out.append(arena, .{ .name = "focused", .value = .{ .boolean_or_undefined = true } });
    if (editableKind(dom)) |kind| try out.append(arena, .{ .name = "editable", .value = .{ .token = kind } });
    if (settable(tree, dom, role)) try out.append(arena, .{ .name = "settable", .value = .{ .boolean_or_undefined = true } });
    // FillWidgetProperties.
    // AutoComplete(): aria-autocomplete, on text fields.
    if (role == .TextField or role == .SearchBox or role == .TextFieldWithComboBox) {
        if (attribute(dom, "aria-autocomplete")) |v| if (v.len > 0 and !std.ascii.eqlIgnoreCase(v, "none")) try out.append(arena, .{ .name = "autocomplete", .value = .{ .token = v } });
    }
    if (hasPopup(dom, role)) |popup| try out.append(arena, .{ .name = "hasPopup", .value = .{ .token = popup } });
    if (hierarchicalLevel(dom, role)) |level| try out.append(arena, .{ .name = "level", .value = .{ .integer = level } });
    switch (role) {
        .Grid, .ListBox, .TabList, .TreeGrid, .Tree => try out.append(arena, .{ .name = "multiselectable", .value = .{ .boolean = multiselectable(dom) } }),
        else => {},
    }
    if (orientation(dom, role)) |o| try out.append(arena, .{ .name = "orientation", .value = .{ .token = o } });
    if (role == .TextField) try out.append(arena, .{ .name = "multiline", .value = .{ .boolean = multiline(dom) } });
    switch (role) {
        .Grid, .GridCell, .TextField, .ColumnHeader, .RowHeader, .TreeGrid => try out.append(arena, .{ .name = "readonly", .value = .{ .boolean = readOnly(dom) } }),
        else => {},
    }
    switch (role) {
        .ComboBoxGrouping, .ComboBoxMenuButton, .GridCell, .ListBox, .RadioGroup, .SpinButton, .TextField, .TextFieldWithComboBox, .Tree, .ColumnHeader, .RowHeader, .TreeGrid => try out.append(arena, .{ .name = "required", .value = .{ .boolean = required(dom) } }),
        else => {},
    }
    if (rangeSupported(tree, dom, role)) {
        try out.append(arena, .{ .name = "valuemin", .value = .{ .number = (try rangeValue(tree, dom, role, .min)) orelse 0 } });
        try out.append(arena, .{ .name = "valuemax", .value = .{ .number = (try rangeValue(tree, dom, role, .max)) orelse 0 } });
        // kValue: the native control's value string (GetValueForControl);
        // an ARIA range sends "" (Chrome 157, the trace's ARIA slider,
        // aria-valuetext notwithstanding).
        try out.append(arena, .{ .name = "valuetext", .value = .{ .string = try nativeValueText(tree, dom) } });
    }
    // FillWidgetStates.
    if (try checkedState(dom, role)) |state| try out.append(arena, .{ .name = if (role == .ToggleButton) "pressed" else "checked", .value = .{ .tristate = state } });
    if (try expandedState(dom, role)) |expanded| try out.append(arena, .{ .name = "expanded", .value = .{ .boolean_or_undefined = expanded } });
    if (try selectedState(dom, role)) |selected| try out.append(arena, .{ .name = "selected", .value = .{ .boolean_or_undefined = selected } });
    if (try modalState(tree, dom, role)) |modal| try out.append(arena, .{ .name = "modal", .value = .{ .boolean = modal } });
    // FillRelationships.
    if (try relatedList(tree, dom, "aria-describedby", true)) |v| try out.append(arena, .{ .name = "describedby", .value = v });
    if (try relatedList(tree, dom, "aria-owns", false)) |v| try out.append(arena, .{ .name = "owns", .value = v });
    // FillSparseAttributes.
    if (attribute(dom, "aria-busy")) |v| if (std.ascii.eqlIgnoreCase(v, "true")) try out.append(arena, .{ .name = "busy", .value = .boolean_one });
    if (try objectUrl(tree, dom, role)) |url| try out.append(arena, .{ .name = "url", .value = .{ .string = url } });
    if (attribute(dom, "aria-keyshortcuts")) |v| if (v.len > 0) try out.append(arena, .{ .name = "keyshortcuts", .value = .{ .string = v } });
    if (attribute(dom, "aria-roledescription")) |v| if (v.len > 0) try out.append(arena, .{ .name = "roledescription", .value = .{ .string = v } });
    if (try activeDescendant(tree, dom, object)) |target| try out.append(arena, .{ .name = "activedescendant", .value = .{ .idref = .{ .node = target } } });
    if (try relatedList(tree, dom, "aria-errormessage", false)) |v| try out.append(arena, .{ .name = "errormessage", .value = v });
    if (try relatedList(tree, dom, "aria-controls", false)) |v| try out.append(arena, .{ .name = "controls", .value = v });
    if (try relatedList(tree, dom, "aria-details", false)) |v| try out.append(arena, .{ .name = "details", .value = v });
    if (try relatedList(tree, dom, "aria-flowto", false)) |v| try out.append(arena, .{ .name = "flowto", .value = v });
    // The name's related-element sources (labelledby: aria-labelledby's
    // targets, the labels, a legend or caption), each with its text.
    if (name_related.len > 0) try out.append(arena, .{ .name = "labelledby", .value = .{ .node_list = name_related } });
}

/// kActivedescendantId: aria-activedescendant's element, when it is in the
/// tree; for a list box <select>, its active selection end (the last
/// selected option: HTMLSelectElement::ActiveSelectionEnd before any user
/// selection).
fn activeDescendant(tree: *Tree, dom: *Instance, object: *const Node) !?*Instance {
    if (attribute(dom, "aria-activedescendant")) |id| {
        const target = @import("element_references.zig").byId(dom, std.mem.trim(u8, id, spaces)) orelse return null;
        if (tree.indexOf(target) == null) return null;
        return target;
    }
    if (object.native_role != .ListBox or dom.stateAs(interfaces.HTMLSelectElement.State) == null) return null;
    var last: ?*Instance = null;
    const base = bridge.getNodeBase(dom).?;
    var at = base.firstChild();
    while (at) |current| : (at = nextNode(current, base)) {
        const n = a11y.instance(current) orelse continue;
        if (n.stateAs(interfaces.HTMLOptionElement.State) == null) continue;
        if (try interfaces.HTMLOptionElement.get_selected(n)) last = n;
    }
    return last;
}

/// The element's live status: aria-live, else its role's implicit one.
fn liveStatus(dom: *Instance, role: Role) ?[]const u8 {
    if (attribute(dom, "aria-live")) |v| {
        if (oneOf(v, .{ "polite", "assertive", "off" })) return v;
    }
    return switch (role) {
        .Alert => "assertive",
        .Log, .Status => "polite",
        .Marquee, .Timer => "off",
        else => null,
    };
}

fn ariaDisabled(dom: *Instance) bool {
    var at: ?*Instance = dom;
    while (at) |element| : (at = a11y.parent(element)) {
        if (bridge.getNodeBase(element).?.node_type != NodeBase.ELEMENT_NODE) return false;
        if (attribute(element, "aria-disabled")) |v| if (std.ascii.eqlIgnoreCase(v, "true")) return true;
    }
    return false;
}

/// GetInvalidState: aria-invalid, else a listed form control's validity.
fn invalidState(tree: *Tree, dom: *Instance) ?[]const u8 {
    _ = tree;
    if (attribute(dom, "aria-invalid")) |v| {
        if (std.ascii.eqlIgnoreCase(v, "false")) return "false";
        if (v.len > 0) return "true";
    }
    if (!isHtml(dom)) return null;
    const tag = localName(dom);
    if (!oneOf(tag, .{ "input", "button", "select", "textarea", "fieldset", "output", "object" })) return null;
    return if (controlValid(dom)) "false" else "true";
}

fn controlValid(dom: *Instance) bool {
    const will = if (dom.stateAs(interfaces.HTMLInputElement.State) != null)
        interfaces.HTMLInputElement.get_willValidate(dom) catch return true
    else if (dom.stateAs(interfaces.HTMLSelectElement.State) != null)
        interfaces.HTMLSelectElement.get_willValidate(dom) catch return true
    else if (dom.stateAs(interfaces.HTMLTextAreaElement.State) != null)
        interfaces.HTMLTextAreaElement.get_willValidate(dom) catch return true
    else
        return true;
    if (!will) return true;
    const validity = if (dom.stateAs(interfaces.HTMLInputElement.State) != null)
        interfaces.HTMLInputElement.get_validity(dom) catch return true
    else if (dom.stateAs(interfaces.HTMLSelectElement.State) != null)
        interfaces.HTMLSelectElement.get_validity(dom) catch return true
    else
        interfaces.HTMLTextAreaElement.get_validity(dom) catch return true;
    if (interfaces.ValidityState.get_valid(validity) catch true) return true;
    // An empty required text field is not reported invalid (the screen
    // reader already says required): IsValidFormControl.
    if (required(dom) and textLength(dom) == 0) return true;
    return false;
}

fn textLength(dom: *Instance) usize {
    if (dom.stateAs(interfaces.HTMLInputElement.State) != null) {
        var value = interfaces.HTMLInputElement.get_value(dom) catch return 0;
        defer value.deinit(dom.ctx.allocator);
        return value.asSlice().len;
    }
    if (dom.stateAs(interfaces.HTMLTextAreaElement.State) != null) {
        var value = interfaces.HTMLTextAreaElement.get_value(dom) catch return 0;
        defer value.deinit(dom.ctx.allocator);
        return value.asSlice().len;
    }
    return 1;
}

/// kFocusable (CanSetFocusAttribute): HTML's focusable areas, and a
/// select's own options unless disabled (Chrome 157 marks every <option>
/// focusable, a11y1-chrome157-trace.txt pages mcp and forms).
fn focusable(tree: *Tree, dom: *Instance, role: Role) bool {
    // A frame's focus is its document's (Chrome 157 sends no focusable on
    // an Iframe, the trace's frames page).
    if (isFrame(dom)) return false;
    if (tree.options.is_focusable(dom)) return true;
    if ((role == .MenuListOption or role == .ListBoxOption) and dom.stateAs(interfaces.HTMLOptionElement.State) != null) return !tree.options.is_disabled(dom);
    return false;
}

fn isFocused(tree: *Tree, dom: *Instance) bool {
    const designation = focused_area.get(tree.document) orelse return false;
    if (!designation.isLive()) return false;
    return designation.element == dom;
}

/// kSetValue (SerializeActionAttributes, only for an unrestricted
/// object): editable text fields and contenteditable textboxes, the value
/// controls, and separators (Chrome 157 sends settable for an <hr>).
fn settable(tree: *Tree, dom: *Instance, role: Role) bool {
    if (tree.options.is_disabled(dom) or ariaDisabled(dom) or readOnly(dom)) return false;
    if (editableKind(dom) != null) {
        if (dom.stateAs(interfaces.HTMLInputElement.State) != null or dom.stateAs(interfaces.HTMLTextAreaElement.State) != null) return true;
        return role == .TextField or role == .SearchBox;
    }
    return switch (role) {
        .Slider, .SpinButton, .ColorWell, .Date, .DateTime, .InputTime, .Splitter => true,
        else => false,
    };
}

fn hasPopup(dom: *Instance, role: Role) ?[]const u8 {
    if (attribute(dom, "aria-haspopup")) |v| {
        if (std.ascii.eqlIgnoreCase(v, "true") or std.ascii.eqlIgnoreCase(v, "menu")) return if (std.ascii.eqlIgnoreCase(v, "true")) "true" else "menu";
        inline for (.{ "listbox", "tree", "grid", "dialog" }) |name| if (std.ascii.eqlIgnoreCase(v, name)) return name;
        if (std.ascii.eqlIgnoreCase(v, "false")) return null;
    }
    // An ARIA combobox implies a listbox pop-up.
    return switch (role) {
        .ComboBoxGrouping, .ComboBoxMenuButton, .TextFieldWithComboBox => "listbox",
        .ComboBoxSelect => "menu",
        else => null,
    };
}

/// kHierarchicalLevel: a heading's level, aria-level on the roles that
/// take it.
fn hierarchicalLevel(dom: *Instance, role: Role) ?i64 {
    if (attribute(dom, "aria-level")) |v| {
        if (std.fmt.parseInt(i64, std.mem.trim(u8, v, spaces), 10)) |n| {
            if (n > 0) return n;
        } else |_| {}
    }
    if (role == .Heading) {
        const tag = localName(dom);
        if (isHtml(dom) and tag.len == 2 and tag[0] == 'h' and tag[1] >= '1' and tag[1] <= '6') return tag[1] - '0';
        return 2;
    }
    // A list item's or tree item's nesting: the lists (trees, groups) it is
    // in (AXObject::HierarchicalLevel).
    if (role == .ListItem or role == .TreeItem) {
        var level: i64 = 0;
        var at = a11y.parent(dom);
        while (at) |ancestor| : (at = a11y.parent(ancestor)) {
            if (bridge.getNodeBase(ancestor).?.node_type != NodeBase.ELEMENT_NODE) break;
            if (role == .ListItem) {
                if (isHtml(ancestor) and oneOf(localName(ancestor), .{ "ul", "ol", "menu" })) level += 1 else if (attribute(ancestor, "role")) |r| {
                    if (std.ascii.eqlIgnoreCase(r, "list")) level += 1;
                }
            } else if (attribute(ancestor, "role")) |r| {
                if (std.ascii.eqlIgnoreCase(r, "tree") or std.ascii.eqlIgnoreCase(r, "group")) level += 1;
                if (std.ascii.eqlIgnoreCase(r, "tree")) break;
            }
        }
        return @max(level, 1);
    }
    return null;
}

fn multiselectable(dom: *Instance) bool {
    if (attribute(dom, "aria-multiselectable")) |v| return std.ascii.eqlIgnoreCase(v, "true");
    return isHtml(dom) and eq(localName(dom), "select") and attribute(dom, "multiple") != null;
}

fn orientation(dom: *Instance, role: Role) ?[]const u8 {
    if (attribute(dom, "aria-orientation")) |v| {
        if (std.ascii.eqlIgnoreCase(v, "vertical")) return "vertical";
        if (std.ascii.eqlIgnoreCase(v, "horizontal")) return "horizontal";
    }
    return switch (role) {
        .ScrollBar, .ListBox, .Menu, .Tree, .TreeGrid => "vertical",
        .MenuBar, .Slider, .Splitter, .TabList, .Toolbar => "horizontal",
        else => null,
    };
}

fn multiline(dom: *Instance) bool {
    if (attribute(dom, "aria-multiline")) |v| return std.ascii.eqlIgnoreCase(v, "true");
    return isHtml(dom) and eq(localName(dom), "textarea");
}

fn readOnly(dom: *Instance) bool {
    if (attribute(dom, "aria-readonly")) |v| return std.ascii.eqlIgnoreCase(v, "true");
    // A cell takes its grid's aria-readonly (AXObject::Restriction).
    if (attribute(dom, "role")) |r| if (oneOf(r, .{ "gridcell", "columnheader", "rowheader" })) {
        var at = a11y.parent(dom);
        while (at) |ancestor| : (at = a11y.parent(ancestor)) {
            if (bridge.getNodeBase(ancestor).?.node_type != NodeBase.ELEMENT_NODE) break;
            const role = attribute(ancestor, "role") orelse continue;
            if (oneOf(role, .{ "grid", "treegrid" })) return if (attribute(ancestor, "aria-readonly")) |v| std.ascii.eqlIgnoreCase(v, "true") else false;
        }
    };
    if (isHtml(dom) and oneOf(localName(dom), .{ "input", "textarea" })) return attribute(dom, "readonly") != null;
    return false;
}

fn required(dom: *Instance) bool {
    if (isHtml(dom) and oneOf(localName(dom), .{ "input", "select", "textarea" }) and attribute(dom, "required") != null) return true;
    if (attribute(dom, "aria-required")) |v| return std.ascii.eqlIgnoreCase(v, "true");
    return false;
}

/// The checked state (CheckedState): native checkedness for checkboxes
/// and radios, aria-checked / aria-pressed on the roles that support them.
fn checkedState(dom: *Instance, role: Role) !?[]const u8 {
    if (role == .ToggleButton) {
        const v = attribute(dom, "aria-pressed") orelse return null;
        if (std.ascii.eqlIgnoreCase(v, "mixed")) return "mixed";
        return if (std.ascii.eqlIgnoreCase(v, "true")) "true" else "false";
    }
    switch (role) {
        .CheckBox, .Switch, .RadioButton, .MenuItemCheckBox, .MenuItemRadio, .TreeItem, .ListBoxOption => {},
        else => return null,
    }
    if (dom.stateAs(interfaces.HTMLInputElement.State) != null) {
        var kind = try interfaces.HTMLInputElement.get_type(dom);
        defer kind.deinit(dom.ctx.allocator);
        if (oneOf(kind.asSlice(), .{ "checkbox", "radio" })) {
            if (eq(kind.asSlice(), "checkbox") and try interfaces.HTMLInputElement.get_indeterminate(dom)) return "mixed";
            return if (try interfaces.HTMLInputElement.get_checked(dom)) "true" else "false";
        }
    }
    const v = attribute(dom, "aria-checked") orelse return switch (role) {
        .CheckBox, .Switch, .RadioButton, .MenuItemCheckBox, .MenuItemRadio => "false",
        else => null,
    };
    if (std.ascii.eqlIgnoreCase(v, "mixed")) return if (role == .RadioButton or role == .Switch or role == .MenuItemRadio) "false" else "mixed";
    return if (std.ascii.eqlIgnoreCase(v, "true")) "true" else "false";
}

fn expandedState(dom: *Instance, role: Role) !?bool {
    if (role == .ComboBoxSelect) return false;
    if (role == .DisclosureTriangle or role == .DisclosureTriangleGrouped) {
        const p = a11y.parent(dom) orelse return null;
        if (isHtml(p) and eq(localName(p), "details")) return try interfaces.HTMLDetailsElement.get_open(p);
    }
    const v = attribute(dom, "aria-expanded") orelse return null;
    if (std.ascii.eqlIgnoreCase(v, "true")) return true;
    if (std.ascii.eqlIgnoreCase(v, "false")) return false;
    return null;
}

/// kSelected: a native option's selectedness; aria-selected where the
/// role supports it and the attribute is there.
fn selectedState(dom: *Instance, role: Role) !?bool {
    switch (role) {
        .ListBoxOption, .MenuListOption, .Tab, .Cell, .GridCell, .ColumnHeader, .RowHeader, .Row, .TreeItem => {
            if (dom.stateAs(interfaces.HTMLOptionElement.State) != null) return try interfaces.HTMLOptionElement.get_selected(dom);
            const v = attribute(dom, "aria-selected") orelse return null;
            return std.ascii.eqlIgnoreCase(v, "true");
        },
        else => return null,
    }
}

fn modalState(tree: *Tree, dom: *Instance, role: Role) !?bool {
    if (role != .Dialog and role != .AlertDialog) return null;
    if (attribute(dom, "aria-modal")) |v| if (std.ascii.eqlIgnoreCase(v, "true")) return true;
    if (isHtml(dom) and eq(localName(dom), "dialog")) {
        // An open modal dialog is in the top layer as modal.
        const layer = (try @import("top_layer.zig").ofDocument(tree.document, false)) orelse return false;
        return layer.findModal(dom) != null;
    }
    return null;
}

/// An IDREF-list relation as CDP's idrefList value, naming each target
/// that is in the tree (AccessibilityChildrenFromAttribute: only
/// describedby and labelledby may name ignored ones).
fn relatedList(tree: *Tree, dom: *Instance, comptime name: []const u8, allow_ignored: bool) !?Value {
    const value = attribute(dom, name) orelse return null;
    var related: std.ArrayListUnmanaged(Related) = .empty;
    var tokens = std.mem.tokenizeAny(u8, value, spaces);
    while (tokens.next()) |id| {
        const target = @import("element_references.zig").byId(dom, id) orelse continue;
        if (!allow_ignored) {
            const index = tree.indexOf(target) orelse continue;
            if (tree.node(index).ignored) continue;
        }
        try related.append(tree.arena, .{ .node = target });
    }
    if (related.items.len == 0) return null;
    return .{ .idref_list = .{ .attribute_value = value, .related = related.items } };
}

/// A link's URL: its href, resolved.
/// AXNodeObject::Url for an element: a link's href, an image's source URL
/// (ImageSourceURL, completed against the document), an image button's src;
/// TruncateAndAddStringAttribute keeps at most 10,000 bytes of it, cut at a
/// character boundary.
fn objectUrl(tree: *Tree, dom: *Instance, role: Role) !?[]const u8 {
    const url = if (role == .Link)
        try linkUrl(tree, dom)
    else if (role == .Image and dom.stateAs(interfaces.HTMLImageElement.State) != null)
        try imageUrl(tree, dom)
    else if (isImageButton(dom))
        try inputImageUrl(tree, dom)
    else
        null;
    const value = url orelse return null;
    if (value.len == 0) return null;
    const max = 10000;
    if (value.len <= max) return value;
    var end: usize = max;
    while (end > 0 and (value[end] & 0xC0) == 0x80) end -= 1;
    return value[0..end];
}

/// HTMLImageElement::ImageSourceURL: its src attribute, stripped of HTML
/// white space; with none, the candidate srcset selected (currentSrc).
fn imageUrl(tree: *Tree, dom: *Instance) !?[]const u8 {
    if (std.mem.trim(u8, attribute(dom, "src") orelse "", spaces).len > 0) {
        const src = try interfaces.HTMLImageElement.get_src(dom);
        defer dom.ctx.allocator.free(src);
        return try tree.arena.dupe(u8, src);
    }
    if (attribute(dom, "srcset") == null) return null;
    const current = try interfaces.HTMLImageElement.get_currentSrc(dom);
    defer dom.ctx.allocator.free(current);
    return try tree.arena.dupe(u8, current);
}

fn isImageButton(dom: *Instance) bool {
    if (dom.stateAs(interfaces.HTMLInputElement.State) == null) return false;
    var kind = interfaces.HTMLInputElement.get_type(dom) catch return false;
    defer kind.deinit(dom.ctx.allocator);
    return eq(kind.asSlice(), "image");
}

/// HTMLInputElement::Src: the src attribute completed against the document.
fn inputImageUrl(tree: *Tree, dom: *Instance) !?[]const u8 {
    if (attribute(dom, "src") == null) return null;
    const src = try interfaces.HTMLInputElement.get_src(dom);
    defer dom.ctx.allocator.free(src);
    return try tree.arena.dupe(u8, src);
}

fn linkUrl(tree: *Tree, dom: *Instance) !?[]const u8 {
    // An SVG link: SVGAElement::HrefURL, href else xlink:href, stripped of
    // HTML white space and completed against the document.
    if (isSvg(dom)) {
        const raw = attribute(dom, "href") orelse xlinkHref(dom) orelse return null;
        const url = (try @import("encoding_parse.zig").encodingParseAndSerializeWithAllocator(tree.arena, dom, std.mem.trim(u8, raw, spaces))) orelse return null;
        return if (absoluteUrl(url)) url else null;
    }
    if (dom.stateAs(interfaces.HTMLAnchorElement.State) == null) return null;
    const href = try interfaces.HTMLAnchorElement.get_href(dom);
    defer dom.ctx.allocator.free(href);
    // HrefURL: an href that does not parse against the base (a path on a
    // data: URL) is no URL - the getter then answers the attribute as is.
    if (href.len == 0 or !absoluteUrl(href)) return null;
    return try tree.arena.dupe(u8, href);
}

/// The length of an attribute's value, 0 when it is absent.
fn attributeLength(element: *Instance, name: []const u8) usize {
    const value = attribute(element, name) orelse return 0;
    return value.len;
}

/// Whether `text` starts with a URL scheme (an absolute URL).
fn absoluteUrl(text: []const u8) bool {
    const colon = std.mem.indexOfScalar(u8, text, ':') orelse return false;
    if (colon == 0 or !std.ascii.isAlphabetic(text[0])) return false;
    for (text[0..colon]) |c| if (!(std.ascii.isAlphanumeric(c) or c == '+' or c == '-' or c == '.')) return false;
    return true;
}

// ============================================================================
// Layout, as the cascade answers it
// ============================================================================

/// Whether `element` has a box: rendered, and not display: contents.
fn hasBox(element: *Instance) !bool {
    if (isSvg(element) and !svgRenders(element)) return false;
    return style.isBeingRendered(element) catch false;
}

/// SVG's rendering model, which CSS display does not express: a never-rendered
/// element (a <title>, <desc>, <metadata>, a paint server, a filter, a
/// <clipPath>, <mask> or <marker>, an animation element) or anything inside
/// one (a <defs>, a <symbol>) makes no layout object (Blink creates no
/// LayoutObject for them: SVGElement::LayoutObjectIsNeeded per element).
fn svgRenders(element: *Instance) bool {
    var at: ?*Instance = element;
    while (at) |n| : (at = a11y.parent(n)) {
        if (!isSvg(n)) break;
        const tag = localName(n);
        if (oneOf(tag, .{ "title", "desc", "metadata", "defs", "symbol", "clipPath", "mask", "pattern", "marker", "linearGradient", "radialGradient", "filter", "style", "script", "set", "mpath" })) return false;
        if (std.mem.startsWith(u8, tag, "fe") or std.mem.startsWith(u8, tag, "animate")) return false;
    }
    return true;
}

/// Whether an SVG element takes text children into layout: <text>, <tspan>,
/// <textPath>, and an <a> inside a <text> (LayoutSVGText / LayoutSVGInline;
/// any other SVG container's IsChildAllowed refuses a text).
fn svgTakesText(element: *Instance) bool {
    const tag = localName(element);
    if (oneOf(tag, .{ "text", "tspan", "textPath" })) return true;
    if (!eq(tag, "a")) return false;
    var at = a11y.parent(element);
    while (at) |n| : (at = a11y.parent(n)) {
        if (!isSvg(n)) return false;
        if (eq(localName(n), "text")) return true;
    }
    return false;
}

/// Whether `element` is rendered or delegates its rendering to children.
fn rendered(element: *Instance) !bool {
    return style.isBeingRenderedOrDelegating(element) catch false;
}

fn isDisplayContents(element: *Instance) !bool {
    const computed = (try style.computedStyle(element, null)) orelse return false;
    return computed.display().box == .contents;
}

/// Whether `element`'s DOM children are laid out: not a replaced element,
/// a form control that renders its own content, or a frame.
fn rendersChildren(element: *Instance) bool {
    if (!isHtml(element)) return true;
    return !oneOf(localName(element), .{ "img", "input", "textarea", "select", "iframe", "frame", "video", "audio", "canvas", "embed", "object", "meter", "progress", "br", "hr", "template" });
}

fn preservesWhiteSpace(element: *Instance) bool {
    const computed = (style.computedStyle(element, null) catch return false) orelse return false;
    return switch (computed.keyword(.white_space_collapse)) {
        .preserve, .break_spaces, .preserve_spaces => true,
        else => false,
    };
}

fn preservesNewlines(element: *Instance) bool {
    const computed = (style.computedStyle(element, null) catch return false) orelse return false;
    return computed.keyword(.white_space_collapse) == .preserve_breaks;
}

fn isInlineLevel(element: *Instance) bool {
    const computed = (style.computedStyle(element, null) catch return false) orelse return false;
    const display = computed.display();
    if (display.box == .none) return false;
    if (display.box == .contents) return true;
    return display.outer == .inline_ and display.box == .normal;
}

fn isPositioned(element: *Instance) !bool {
    const computed = (try style.computedStyle(element, null)) orelse return false;
    return computed.keyword(.position) != .static;
}

/// Text::TextLayoutObjectIsNeeded for white space (with
/// CanHaveWhitespaceChildren): table parts, flex and grid containers take
/// none unless it follows text that does not end in white space; preserved
/// breaks always make one; otherwise one follows inline content that is not
/// a <br> or text ending in white space, or starts an inline parent.
fn whitespaceNeedsLayout(tree: *Tree, text: *Instance, parent_element: *Instance) bool {
    if (tree.whitespace_layout.get(text)) |known| return known;
    const result = whitespaceNeedsLayoutOnce(tree, text, parent_element);
    tree.whitespace_layout.put(tree.arena, text, result) catch {};
    return result;
}

fn whitespaceNeedsLayoutOnce(tree: *Tree, text: *Instance, parent_element: *Instance) bool {
    const prev = previousInFlow(tree, text);
    if (!canHaveWhitespaceChildren(parent_element)) {
        const p = prev orelse return false;
        if (!isText(p)) return false;
        return preservesBreaks(parent_element) or !endsWithWhitespace(p);
    }
    if (preservesBreaks(parent_element)) return true;
    const p = prev orelse return isInlineLevel(parent_element) and !isDisplayContentsElement(parent_element);
    if (isText(p)) return !endsWithWhitespace(p);
    return isInlineLevel(p) and !(isHtml(p) and eq(localName(p), "br"));
}

fn canHaveWhitespaceChildren(element: *Instance) bool {
    const computed = (style.computedStyle(element, null) catch return true) orelse return true;
    const display = computed.display();
    if (display.box == .internal) switch (display.internal) {
        .table_row_group, .table_header_group, .table_footer_group, .table_row, .table_column_group, .table_column => return false,
        else => {},
    };
    if (display.box == .normal and (display.inner == .table or display.inner == .flex or display.inner == .grid)) return false;
    return !isSvg(element) or eq(localName(element), "text");
}

fn preservesBreaks(element: *Instance) bool {
    const computed = (style.computedStyle(element, null) catch return false) orelse return false;
    return switch (computed.keyword(.white_space_collapse)) {
        .preserve, .preserve_breaks, .break_spaces => true,
        else => false,
    };
}

fn isWhitespaceText(text: *Instance) bool {
    var value = interfaces.CharacterData.get_data(text) catch return false;
    defer value.deinit(text.ctx.allocator);
    return std.mem.trim(u8, value.asSlice(), spaces).len == 0;
}

fn endsWithWhitespace(text: *Instance) bool {
    var value = interfaces.CharacterData.get_data(text) catch return false;
    defer value.deinit(text.ctx.allocator);
    const bytes = value.asSlice();
    if (bytes.len == 0) return false;
    return std.mem.indexOfScalar(u8, spaces, bytes[bytes.len - 1]) != null;
}

/// The previous in-flow sibling with a layout object: an element with a
/// box that is not out of flow, a display: contents element, or a text
/// that has a LayoutText (white space that made none is skipped).
fn previousInFlow(tree: *Tree, n: *Instance) ?*Instance {
    var at = (bridge.getNodeBase(n) orelse return null).previousSibling();
    var depth: usize = 0;
    while (at) |current| : (at = current.previousSibling()) {
        const s = a11y.instance(current) orelse continue;
        if (current.node_type == NodeBase.ELEMENT_NODE) {
            if (isDisplayContents(s) catch false) return s;
            if (!(hasBox(s) catch false)) continue;
            if (outOfFlow(s)) continue;
            return s;
        } else if (current.node_type == NodeBase.TEXT_NODE or current.node_type == NodeBase.CDATA_SECTION_NODE) {
            var value = interfaces.CharacterData.get_data(s) catch continue;
            defer value.deinit(s.ctx.allocator);
            const bytes = value.asSlice();
            if (bytes.len == 0) continue;
            if (std.mem.trim(u8, bytes, spaces).len != 0) return s;
            // White space: in flow only if it made a LayoutText itself.
            depth += 1;
            if (depth > 8) return null;
            const p = a11y.parent(s) orelse return null;
            if (whitespaceNeedsLayout(tree, s, p)) return s;
        }
    }
    return null;
}

fn outOfFlow(element: *Instance) bool {
    const computed = (style.computedStyle(element, null) catch return false) orelse return false;
    const position = computed.keyword(.position);
    if (position == .absolute or position == .fixed) return true;
    return computed.keyword(.float) != .none;
}

fn isDisplayContentsElement(element: *Instance) bool {
    return isDisplayContents(element) catch false;
}

fn isText(n: *Instance) bool {
    const t = bridge.getNodeBase(n).?.node_type;
    return t == NodeBase.TEXT_NODE or t == NodeBase.CDATA_SECTION_NODE;
}

/// CanIgnoreSpace (which, despite its name, says the white space is
/// relevant): kept when it has DOM neighbours (the previous absolute sibling
/// and the next node skipping children, climbing to ancestors), neither of
/// which already separates it, and any text neighbour is in the same block.
fn canKeepSpace(text: *Instance) bool {
    const prev = absoluteSibling(text, false) orelse return false;
    const next = absoluteSibling(text, true) orelse return false;
    if (spaceSeparated(prev, false, 0) or spaceSeparated(next, true, 0)) return false;
    const box = enclosingBlock(text);
    if (isText(prev) and enclosingBlock(prev) != box) return false;
    if (isText(next) and enclosingBlock(next) != box) return false;
    return true;
}

/// NodeTraversal::PreviousAbsoluteSibling / NextSkippingChildren: the
/// sibling, or the nearest ancestor's.
fn absoluteSibling(n: *Instance, forward: bool) ?*Instance {
    var at: ?*NodeBase = bridge.getNodeBase(n);
    while (at) |current| : (at = current.parent_node) {
        var sibling = if (forward) current.next_sibling else current.previousSibling();
        while (sibling) |candidate| : (sibling = if (forward) candidate.next_sibling else candidate.previousSibling()) {
            if (candidate.node_type == NodeBase.ELEMENT_NODE or candidate.node_type == NodeBase.TEXT_NODE) return a11y.instance(candidate);
        }
        const p = current.parent_node orelse return null;
        if (p.node_type != NodeBase.ELEMENT_NODE) return null;
    }
    return null;
}

/// The nearest ancestor that is not inline-level (LayoutText::EnclosingBox).
fn enclosingBlock(n: *Instance) ?*Instance {
    var at = a11y.parent(n);
    while (at) |p| : (at = a11y.parent(p)) {
        if (bridge.getNodeBase(p).?.node_type != NodeBase.ELEMENT_NODE) return p;
        if (!isInlineLevel(p)) return p;
    }
    return null;
}

/// CanIgnoreSpaceNextTo: whether a neighbour already separates the space.
fn spaceSeparated(n: *Instance, is_after: bool, counter: usize) bool {
    if (counter > 3) return false;
    if (isText(n)) {
        var value = interfaces.CharacterData.get_data(n) catch return false;
        defer value.deinit(n.ctx.allocator);
        const bytes = value.asSlice();
        if (bytes.len == 0) return false;
        if (std.mem.trim(u8, bytes, spaces).len == 0) return true;
        const c = if (is_after) bytes[0] else bytes[bytes.len - 1];
        return c == ' ' or c == '\n' or c == '\t';
    }
    if (!(hasBox(n) catch false) and !isDisplayContentsElement(n)) return true;
    if (isHtml(n) and eq(localName(n), "br")) return !is_after or attribute(n, "role") == null;
    if (isHtml(n) and eq(localName(n), "img")) return false;
    if (isHtml(n) and eq(localName(n), "input")) {
        if (attribute(n, "type")) |t| if (std.ascii.eqlIgnoreCase(t, "image")) return false;
    }
    // Not a LayoutInline: a block, or an atomic inline.
    if (!isLayoutInline(n)) return true;
    if (attribute(n, "role")) |r| if (oneOf(r, .{ "cell", "gridcell", "columnheader", "rowheader" })) return true;
    const base = bridge.getNodeBase(n).?;
    const child = if (is_after) base.firstChild() else base.lastChild();
    if (child) |c| {
        const inner = a11y.instance(c) orelse return false;
        return spaceSeparated(inner, is_after, counter + 1);
    }
    const adjacent = absoluteSibling(n, is_after) orelse return true;
    return spaceSeparated(adjacent, is_after, counter + 1);
}

/// A LayoutInline: display inline, not replaced and not atomic.
fn isLayoutInline(element: *Instance) bool {
    const computed = (style.computedStyle(element, null) catch return false) orelse return false;
    const display = computed.display();
    if (display.box != .normal or display.outer != .inline_ or display.inner != .flow) return false;
    return rendersChildren(element);
}

/// Hidden by style (ComputeIsHiddenViaStyle): visibility other than
/// visible; for an element with no box, display: none on it or an ancestor
/// (a display: contents element is not hidden).
fn hiddenViaStyle(element: *Instance, has_layout: bool) !bool {
    const computed = (try style.computedStyle(element, null)) orelse return true;
    if (has_layout) return computed.keyword(.visibility) != .visible;
    if (computed.display().box == .contents and try rendered(element)) return computed.keyword(.visibility) != .visible;
    return true;
}

/// A block flow whose children are inline-level (LayoutBlockFlow
/// ChildrenInline() with a first child).
fn parentsInlineChildren(element: *Instance) !bool {
    const computed = (try style.computedStyle(element, null)) orelse return false;
    const display = computed.display();
    // A LayoutBlockFlow: a block or inline-block container, a list item, a
    // table cell or caption - not an inline box (LayoutInline).
    const block_flow = switch (display.box) {
        .normal => (display.inner == .flow and display.outer == .block) or display.inner == .flow_root,
        .internal => display.internal == .table_cell or display.internal == .table_caption,
        else => false,
    };
    if (!block_flow) return false;
    if (!rendersChildren(element)) return false;
    var any = false;
    const base = bridge.getNodeBase(element).?;
    var at = base.firstChild();
    while (at) |current| : (at = current.next_sibling) {
        const n = a11y.instance(current) orelse continue;
        if (current.node_type == NodeBase.ELEMENT_NODE) {
            if (!(hasBox(n) catch false) and !isDisplayContentsElement(n)) continue;
            if (!isInlineLevel(n)) return false;
            any = true;
        } else if (current.node_type == NodeBase.TEXT_NODE) {
            var value = interfaces.CharacterData.get_data(n) catch continue;
            defer value.deinit(n.ctx.allocator);
            if (std.mem.trim(u8, value.asSlice(), spaces).len > 0) any = true;
        }
    }
    // Generated ::before/::after content is an inline child too.
    const pseudos = style.generatedPseudos(element);
    if (pseudos.before or pseudos.after) any = true;
    return any;
}

/// AXNodeObject::IsLineBreakingObject: never for a presentational object;
/// an enclosing block (display block, inline-block, flow-root, list-item,
/// flex, grid, table parts: Blink Editing's IsEnclosingBlock, which needs a
/// layout object - a display: contents element is none, Chrome 157 leaving
/// one out of the tree, the trace's shadow page) or a <br>; otherwise by
/// role (AXObject's: a structure role that is not an image, outside SVG).
fn isLineBreakingObject(element: *Instance, role: Role) bool {
    if (role == .None) return false;
    if (isHtml(element) and eq(localName(element), "br")) return true;
    if (style.computedStyle(element, null) catch null) |computed| {
        const display = computed.display();
        switch (display.box) {
            .internal => return true,
            .normal => if (display.outer == .block or display.inner != .flow or display.list_item) return true,
            .contents, .none => {},
        }
    }
    if (role == .Image or isSvg(element)) return false;
    return isStructure(role);
}

/// ui::IsStructure (ax_role_properties.cc): sections, section heads, the
/// presentational role, and the document structure roles.
fn isStructure(role: Role) bool {
    return switch (role) {
        // IsLandmark.
        .Banner, .Complementary, .ContentInfo, .Form, .Main, .Navigation, .Region, .Search => true,
        // IsSelect.
        .ComboBoxGrouping, .ListBox, .Menu, .MenuBar, .RadioGroup, .Tree, .TreeGrid => true,
        // IsSection's own.
        .Alert, .AlertDialog, .Cell, .ColumnHeader, .Definition, .Feed, .Figure, .Grid, .GridCell, .Group, .Image, .List, .ListItem, .Log, .Marquee, .Math, .MathMLMath, .MathMLTableCell, .Note, .ProgressIndicator, .Row, .RowHeader, .Section, .Status, .Table, .TabPanel, .Term, .Timer, .Toolbar, .Tooltip, .TreeItem => true,
        // IsSectionhead.
        .Heading, .Tab => true,
        // IsPresentational.
        .None => true,
        .Application, .Document, .Article, .RowGroup, .Splitter => true,
        .DocAbstract, .DocAcknowledgments, .DocAfterword, .DocAppendix, .DocBiblioEntry, .DocBibliography, .DocChapter, .DocColophon, .DocConclusion, .DocCover, .DocCredit, .DocCredits, .DocDedication, .DocEndnote, .DocEndnotes, .DocEpigraph, .DocEpilogue, .DocErrata, .DocExample, .DocFootnote, .DocForeword, .DocGlossary, .DocIndex, .DocIntroduction, .DocNotice, .DocPageBreak, .DocPageList, .DocPart, .DocPreface, .DocPrologue, .DocQna, .DocSubtitle, .DocTip, .DocToc => true,
        else => false,
    };
}

// ============================================================================
// Role helpers
// ============================================================================

fn isFrame(n: *Instance) bool {
    return isHtml(n) and oneOf(localName(n), .{ "iframe", "frame", "fencedframe" });
}

/// The first <map> in `root`'s subtree whose name (or, with none, id) is
/// `name` (HTML 4.8.14 "rules for parsing a hash-name reference").
fn findMap(root: *NodeBase, name: []const u8) ?*Instance {
    var at = nextInSubtree(root, root);
    while (at) |current| : (at = nextInSubtree(current, root)) {
        const element = a11y.instance(current) orelse continue;
        if (current.node_type != NodeBase.ELEMENT_NODE or !isHtml(element) or !eq(localName(element), "map")) continue;
        if (attribute(element, "name")) |n| if (eq(n, name)) return element;
        if (attribute(element, "id")) |id| if (eq(id, name)) return element;
    }
    return null;
}

/// The next node after `node` in tree order inside `boundary`'s subtree.
fn nextInSubtree(node: *NodeBase, boundary: *NodeBase) ?*NodeBase {
    if (node.firstChild()) |child| return child;
    var at = node;
    while (at != boundary) {
        if (at.next_sibling) |sibling| return sibling;
        at = at.parent_node orelse return null;
    }
    return null;
}

fn xlinkHref(n: *Instance) ?[]const u8 {
    const element = data.of(n) orelse return null;
    return if (element.findAttribute("http://www.w3.org/1999/xlink", "href")) |entry| entry.value else null;
}

fn firstElementChild(n: *Instance) ?*Instance {
    var at = bridge.getNodeBase(n).?.firstChild();
    while (at) |child| : (at = child.next_sibling) if (child.node_type == NodeBase.ELEMENT_NODE) return a11y.instance(child);
    return null;
}

fn isSvg(n: *Instance) bool {
    const element = data.of(n) orelse return false;
    return eq(element.namespaceSlice() orelse "", "http://www.w3.org/2000/svg");
}

fn svgParent(n: *Instance) bool {
    const p = a11y.parent(n) orelse return false;
    return isSvg(p);
}

/// IsPotentialInPageLinkTarget: an <a name>, or an element with an id -
/// not in a shadow tree, not SVG, not a label or an optgroup.
fn isPotentialInPageLinkTarget(element: *Instance) bool {
    if (isSvg(element)) return false;
    if (inShadowTree(element)) return false;
    if (isHtml(element) and eq(localName(element), "a") and attribute(element, "name") != null) return true;
    const id = attribute(element, "id") orelse return false;
    if (id.len == 0) return false;
    return !(isHtml(element) and oneOf(localName(element), .{ "label", "optgroup" }));
}

fn inShadowTree(element: *Instance) bool {
    var at = bridge.getNodeBase(element).?.parent_node;
    while (at) |p| : (at = p.parent_node) {
        if (p.node_type == NodeBase.DOCUMENT_FRAGMENT_NODE) {
            const n = a11y.instance(p) orelse return false;
            return n.implements(interfaces.ShadowRoot.State);
        }
    }
    return false;
}

/// A custom element (Element::IsCustomElement): an autonomous one that is
/// defined. An undefined one is an ordinary element (Chrome 157: the trace's
/// <my-el> is not in the tree).
fn isCustomElement(n: *Instance) bool {
    if (!isHtml(n) or std.mem.indexOfScalar(u8, localName(n), '-') == null) return false;
    return @import("custom_elements.zig").isDefined(n);
}

/// ButtonRoleType: toggle button with aria-pressed, pop-up button with a
/// pop-up other than a dialog.
fn buttonRole(dom: *Instance) Role {
    if (attribute(dom, "aria-pressed")) |value| if (value.len > 0 and !std.ascii.eqlIgnoreCase(value, "undefined")) return .ToggleButton;
    if (attribute(dom, "aria-haspopup")) |value| {
        if (value.len > 0 and !std.ascii.eqlIgnoreCase(value, "false") and !std.ascii.eqlIgnoreCase(value, "dialog")) return .PopUpButton;
    }
    return .Button;
}

fn comboboxMenuButton(dom: *Instance) bool {
    // ShouldUseComboboxMenuButtonRole: a focusable element whose combobox
    // role is not on a text field and that has no text-field descendant.
    if (attribute(dom, "aria-haspopup")) |value| if (std.ascii.eqlIgnoreCase(value, "dialog")) return false;
    if (attribute(dom, "contenteditable") != null) return false;
    return attribute(dom, "tabindex") != null;
}

fn usesMenuList(select: *Instance) bool {
    if (attribute(select, "multiple") != null) return false;
    const size = attribute(select, "size") orelse return true;
    const n = std.fmt.parseInt(i64, std.mem.trim(u8, size, spaces), 10) catch return true;
    return n <= 1;
}

fn owningSelect(option: *Instance) ?*Instance {
    var at = a11y.parent(option);
    var depth: usize = 0;
    while (at) |ancestor| : (at = a11y.parent(ancestor)) {
        if (!isHtml(ancestor)) return null;
        const tag = localName(ancestor);
        if (eq(tag, "select")) return ancestor;
        if (eq(tag, "datalist")) return null;
        if (!eq(tag, "optgroup") or depth > 0) return null;
        depth += 1;
    }
    return null;
}

/// ShouldIgnoreListItem: an <li> whose native list (ul, ol, menu) has an
/// ARIA role other than list or directory is presentational.
fn ignoredListItem(li: *Instance) bool {
    const p = a11y.parent(li) orelse return false;
    if (!isHtml(p) or !oneOf(localName(p), .{ "ul", "ol", "menu" })) return false;
    const value = attribute(p, "role") orelse return false;
    if (value.len == 0) return false;
    return !eq(value, "list") and !eq(value, "directory");
}

fn decideHeaderFromSiblings(cell: *Instance) Role {
    const prev = siblingElement(cell, false);
    const next = siblingElement(cell, true);
    if (prev == null and next == null) return .ColumnHeader;
    if (isHeaderCell(next) and isHeaderCell(prev)) return .ColumnHeader;
    if (isNonEmptyDataCell(next) or isNonEmptyDataCell(prev)) return .RowHeader;
    return .ColumnHeader;
}

fn siblingElement(n: *Instance, forward: bool) ?*Instance {
    var at = if (forward) bridge.getNodeBase(n).?.next_sibling else bridge.getNodeBase(n).?.previousSibling();
    while (at) |current| : (at = if (forward) current.next_sibling else current.previousSibling()) {
        if (current.node_type == NodeBase.ELEMENT_NODE) return a11y.instance(current);
    }
    return null;
}

fn isHeaderCell(n: ?*Instance) bool {
    const cell = n orelse return false;
    return isHtml(cell) and eq(localName(cell), "th");
}

fn isNonEmptyDataCell(n: ?*Instance) bool {
    const cell = n orelse return false;
    return isHtml(cell) and eq(localName(cell), "td") and bridge.getNodeBase(cell).?.firstChild() != null;
}

/// The internal role of an ARIA role name (AriaRoleToInternalRole), or
/// Unknown.
pub fn ariaToInternal(token: []const u8) Role {
    const name = a11y.canonicalRole(token) orelse return .Unknown;
    if (eq(name, "image")) return .Image;
    if (eq(name, "none")) return .None;
    inline for (@typeInfo(Role).@"enum".field_values) |value| {
        const role: Role = @fromBackingInt(value);
        if (roles.ariaName(role)) |aria| if (eq(aria, name) and isPrimaryInternal(role)) return role;
    }
    return .Unknown;
}

/// The first internal role of an ARIA role (aria_properties.json5's
/// `internalRoles[0]`), where several map to one name.
fn isPrimaryInternal(role: Role) bool {
    return switch (role) {
        .Header, .PopUpButton, .ToggleButton, .ComboBoxMenuButton, .ComboBoxSelect, .TextFieldWithComboBox, .Footer, .SectionWithoutName, .Details, .MenuListOption => false,
        else => true,
    };
}

fn hasRequiredParentContext(tree: *Tree, dom: *Instance, role: Role) bool {
    const wanted: []const Role = switch (role) {
        .ListItem => &.{ .List, .Group },
        .ListBoxOption => &.{ .ListBox, .Group },
        .TreeItem => &.{ .Tree, .Group },
        else => return true,
    };
    // An owned item's context is its aria-owns owner (IsOrphanedListItem).
    if (tree.names.ownerOf(dom)) |owner| if (attribute(owner, "role")) |value| {
        var tokens = std.mem.tokenizeAny(u8, value, spaces);
        while (tokens.next()) |token| {
            const owner_role = ariaToInternal(token);
            if (owner_role == .Unknown) continue;
            for (wanted) |w| if (owner_role == w) return true;
            break;
        }
    };
    var at = a11y.parent(dom);
    while (at) |p| : (at = a11y.parent(p)) {
        if (bridge.getNodeBase(p).?.node_type != NodeBase.ELEMENT_NODE) continue;
        if (role == .ListItem and isHtml(p) and oneOf(localName(p), .{ "ul", "ol", "menu" })) return true;
        if (role == .ListBoxOption and isHtml(p) and eq(localName(p), "select")) return true;
        // The parent's role attribute, else its ElementInternals role
        // (custom-elements/ElementInternals-role.html "Applies parent/child
        // relationship ... via Element Internals": Chrome 157, Firefox 160
        // and Safari 27.2 all pass).
        const value = (a11y.effective(tree.arena, p, "role", "role") catch null) orelse "";
        var parent_role: Role = .Unknown;
        var tokens = std.mem.tokenizeAny(u8, value, spaces);
        while (tokens.next()) |token| {
            parent_role = ariaToInternal(token);
            if (parent_role != .Unknown) break;
        }
        for (wanted) |w| if (parent_role == w) return true;
        if (role == .TreeItem and parent_role == .TreeItem) continue;
        if (parent_role == .None) continue;
        if (value.len == 0 and isHtml(p) and oneOf(localName(p), .{ "div", "span" })) continue;
        return false;
    }
    return false;
}

fn supportsFocusAttr(dom: *Instance) bool {
    return attribute(dom, "tabindex") != null;
}

fn isEditableRoot(dom: *Instance) bool {
    const value = attribute(dom, "contenteditable") orelse return false;
    if (!(value.len == 0 or std.ascii.eqlIgnoreCase(value, "true") or std.ascii.eqlIgnoreCase(value, "plaintext-only"))) return false;
    // The root: no editable parent.
    const p = a11y.parent(dom) orelse return true;
    const parent_value = attribute(p, "contenteditable") orelse return true;
    return std.ascii.eqlIgnoreCase(parent_value, "false");
}

/// Any ARIA attribute but those that do not make an object interesting
/// (ElementHasAnyAriaAttribute).
fn hasAnyAria(dom: *Instance) bool {
    const element = data.of(dom) orelse return false;
    var i: usize = 0;
    while (element.attributeAt(i)) |attr| : (i += 1) {
        if (attr.namespace_uri != null) continue;
        const name = attr.local_name;
        if (std.mem.startsWith(u8, name, "aria-")) return true;
    }
    return false;
}

/// AXObject::SupportsNameFromContents(recursive = false), by role: ARIA's
/// name-from-contents roles and Blink's own.
fn supportsNameFromContents(role: Role) bool {
    return switch (role) {
        .Button, .Cell, .CheckBox, .ColumnHeader, .DocBackLink, .DocBiblioRef, .DocGlossRef, .DocNoteRef, .DocSubtitle, .GraphicsObject, .GridCell, .Heading, .Link, .ListBoxOption, .MenuItem, .MenuItemCheckBox, .MenuItemRadio, .MenuListOption, .PopUpButton, .RadioButton, .RowHeader, .SectionHeader, .Switch, .Tab, .ToggleButton, .Tooltip, .TreeItem => true,
        .DisclosureTriangle, .DisclosureTriangleGrouped, .LayoutTableCell, .LineBreak, .ListMarker, .StaticText, .Term, .Math => true,
        else => false,
    };
}

/// Element::IsFormControlElement (HTMLFormControlElement's subclasses).
fn isFormControlElement(element: *Instance) bool {
    return isHtml(element) and oneOf(localName(element), .{ "button", "fieldset", "input", "select", "textarea", "output" });
}

fn isHeading(role: Role) bool {
    return role == .Heading or role == .DocSubtitle;
}

fn isTableLike(role: Role) bool {
    return switch (role) {
        .Table, .Grid, .TreeGrid, .LayoutTable => true,
        else => false,
    };
}

fn isTableRowLike(role: Role) bool {
    return role == .Row or role == .LayoutTableRow;
}

fn isTableCellLike(role: Role) bool {
    return switch (role) {
        .Cell, .GridCell, .ColumnHeader, .RowHeader, .LayoutTableCell => true,
        else => false,
    };
}

/// ui::IsControl.
fn isControl(role: Role) bool {
    return switch (role) {
        .Button, .CheckBox, .ColorWell, .ComboBoxMenuButton, .ComboBoxSelect, .Date, .DateTime, .DisclosureTriangle, .DisclosureTriangleGrouped, .InputTime, .ListBox, .MenuBar, .MenuItem, .MenuItemCheckBox, .MenuItemRadio, .PopUpButton, .RadioButton, .ScrollBar, .SearchBox, .Slider, .SpinButton, .Switch, .Tab, .TextField, .TextFieldWithComboBox, .ToggleButton, .Tree, .Menu, .ListBoxOption, .TreeItem, .Toolbar, .TabList, .RadioGroup, .ComboBoxGrouping => true,
        else => false,
    };
}

fn alwaysIncluded(role: Role) bool {
    return switch (role) {
        .Abbr, .Application, .Article, .Audio, .Banner, .Blockquote, .Code, .Complementary, .ContentDeletion, .ContentInfo, .ContentInsertion, .Definition, .DescriptionList, .Details, .Dialog, .DocAcknowledgments, .DocAfterword, .DocAppendix, .DocBibliography, .DocChapter, .DocConclusion, .DocCredits, .DocEndnotes, .DocEpilogue, .DocErrata, .DocForeword, .DocGlossary, .DocIntroduction, .DocPart, .DocPreface, .DocPrologue, .DocToc, .Emphasis, .Figcaption, .Figure, .Footer, .Form, .Header, .List, .ListItem, .Main, .Mark, .Math, .MathMLMath, .MathMLFraction, .MathMLIdentifier, .MathMLMultiscripts, .MathMLNoneScript, .MathMLNumber, .MathMLOperator, .MathMLOver, .MathMLPrescriptDelimiter, .MathMLRoot, .MathMLRow, .MathMLSquareRoot, .MathMLStringLiteral, .MathMLSub, .MathMLSubSup, .MathMLSup, .MathMLTable, .MathMLTableCell, .MathMLTableRow, .MathMLText, .MathMLUnder, .MathMLUnderOver, .Meter, .MenuBar, .MenuItem, .MenuItemCheckBox, .MenuItemRadio, .MenuListOption, .MenuListPopup, .Navigation, .PluginObject, .ProgressIndicator, .Region, .Ruby, .Search, .Section, .Splitter, .Subscript, .Superscript, .Strong, .Term, .Time, .Video => true,
        else => false,
    };
}

/// AXObject::CanHaveChildren(Element).
fn canHaveChildren(element: *Instance) bool {
    if (!isHtml(element)) return true;
    const tag = localName(element);
    if (oneOf(tag, .{ "map", "img", "hr", "progress" })) return false;
    if (eq(tag, "br")) return bridge.getNodeBase(element).?.firstChild() == null;
    if (eq(tag, "input")) {
        var kind = interfaces.HTMLInputElement.get_type(element) catch return true;
        defer kind.deinit(element.ctx.allocator);
        return !oneOf(kind.asSlice(), .{ "checkbox", "radio", "range" });
    }
    if (eq(tag, "option")) return false;
    return true;
}

/// The ::marker's text (ListMarker::TextAlternative): its content, else
/// the list style's marker - a glyph and a space for the symbolic styles,
/// the item's ordinal and ". " for the numeric ones.
fn markerText(arena: Allocator, element: *Instance, out: *std.ArrayListUnmanaged(u8)) !void {
    const computed = (try style.computedStyle(element, "marker")) orelse return;
    const value = computed.get(.content);
    if (value == .content) {
        try value.content.appendAccessible(out, arena);
        return;
    }
    const own = (try style.computedStyle(element, null)) orelse return;
    const kind = own.get(.list_style_type);
    var buffer: [32]u8 = undefined;
    const name: []const u8 = switch (kind) {
        .keyword => |k| @tagName(k),
        .text => |t| blk: {
            // A string is the marker itself; an identifier names a style.
            if (t.bytes.len >= 2 and t.bytes[0] == '"') return out.appendSlice(arena, t.bytes[1 .. t.bytes.len - 1]);
            const n = @min(t.bytes.len, buffer.len);
            for (t.bytes[0..n], 0..) |c, i| buffer[i] = if (c == '-') '_' else c;
            break :blk buffer[0..n];
        },
        else => "disc",
    };
    if (eq(name, "none")) return;
    if (eq(name, "disc")) return out.appendSlice(arena, "\u{2022} ");
    if (eq(name, "circle")) return out.appendSlice(arena, "\u{25E6} ");
    if (eq(name, "square")) return out.appendSlice(arena, "\u{25AA} ");
    if (eq(name, "disclosure_open")) return out.appendSlice(arena, "\u{25BE} ");
    if (eq(name, "disclosure_closed")) return out.appendSlice(arena, "\u{25B8} ");
    const ordinal = listItemOrdinal(element);
    if (eq(name, "lower_alpha") or eq(name, "lower_latin") or eq(name, "upper_alpha") or eq(name, "upper_latin")) {
        if (ordinal >= 1 and ordinal <= 26) {
            const base: u8 = if (name[0] == 'l') 'a' else 'A';
            try out.append(arena, base + @as(u8, @intCast(ordinal - 1)));
            return out.appendSlice(arena, ". ");
        }
    }
    try out.print(arena, "{d}. ", .{ordinal});
}

/// The list item's ordinal: its ol's start (or 1), counted over the list
/// items before it, an item's value attribute resetting the count.
fn listItemOrdinal(li: *Instance) i64 {
    var ordinal: i64 = 1;
    var counted: i64 = 0;
    const p = a11y.parent(li);
    if (p) |list| if (isHtml(list) and eq(localName(list), "ol")) {
        if (attribute(list, "start")) |start| ordinal = std.fmt.parseInt(i64, std.mem.trim(u8, start, spaces), 10) catch 1;
    };
    const base = bridge.getNodeBase(li) orelse return ordinal;
    const parent_base = base.parent_node orelse return ordinal;
    var at = parent_base.firstChild();
    while (at) |current| : (at = current.next_sibling) {
        const n = a11y.instance(current) orelse continue;
        if (current.node_type != NodeBase.ELEMENT_NODE or !isHtml(n) or !eq(localName(n), "li")) continue;
        if (attribute(n, "value")) |v| if (std.fmt.parseInt(i64, std.mem.trim(u8, v, spaces), 10)) |value| {
            ordinal = value;
            counted = 0;
        } else |_| {};
        if (current == base) return ordinal + counted;
        counted += 1;
    }
    return ordinal + counted;
}

/// The glyph of an open-quote or close-quote at the outermost level, for
/// `quotes: auto` in English (“ and ”).
fn quoteGlyph(name: []const u8, kind: PseudoKind) ?[]const u8 {
    _ = kind;
    if (eq(name, "open-quote")) return "\u{201C}";
    if (eq(name, "close-quote")) return "\u{201D}";
    return null;
}

fn nextNode(node: *NodeBase, boundary: *NodeBase) ?*NodeBase {
    if (node.firstChild()) |child| return child;
    var at = node;
    while (at != boundary) {
        if (at.next_sibling) |sibling| return sibling;
        at = at.parent_node orelse return null;
    }
    return null;
}

test "ARIA role names map to Chromium's first internal role" {
    try std.testing.expectEqual(Role.Button, ariaToInternal("button"));
    try std.testing.expectEqual(Role.Image, ariaToInternal("img"));
    try std.testing.expectEqual(Role.None, ariaToInternal("presentation"));
    try std.testing.expectEqual(Role.ComboBoxGrouping, ariaToInternal("combobox"));
    try std.testing.expectEqual(Role.TextField, ariaToInternal("textbox"));
    try std.testing.expectEqual(Role.ListBoxOption, ariaToInternal("option"));
    try std.testing.expectEqual(Role.Banner, ariaToInternal("banner"));
    try std.testing.expectEqual(Role.GenericContainer, ariaToInternal("generic"));
    try std.testing.expectEqual(Role.Unknown, ariaToInternal("widget"));
}
