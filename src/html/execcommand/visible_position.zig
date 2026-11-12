//! Visible positions: where a caret can be, and how Selection.modify moves
//! it by a character or a word.
//!
//! The design is Blink's VisiblePosition model (core/editing/
//! visible_units.cc, editing_utilities.cc, position.cc, position_iterator.cc,
//! position_units.cc, position_units_word.cc, selection_modifier.cc at
//! chromium main 2026-11), which WebKit shares (VisiblePosition::next /
//! previous, Position::upstream / downstream, Position::isCandidate,
//! nextVisuallyDistinctCandidate in VisibleUnits.cpp / Editing.cpp). Only
//! the design is taken; the code is Crane's. The DOM positions it walks are
//! Blink's positions (an anchor node with an offset, or before / after it,
//! or after its children), and its iterator visits them in Blink's order.
//!
//! Blink asks its layout tree four questions: does a node have a layout
//! object, is it visible, is it a block, which characters of a Text are
//! collapsed. Crane draws nothing, so every one of them is answered by the
//! style system alone (no geometry; the deliberate exclusion stands):
//! - a layout object: the element is being rendered (dom.style, flat tree,
//!   no display: none, not display: contents); a Text when its parent is,
//!   by Blink's Text::TextLayoutObjectIsNeeded rules for white-space-only
//!   text;
//! - collapsed characters: CSS Text 3 section 4.1.1 white-space processing
//!   over the inline formatting context, with the line-start and line-end
//!   removals Blink's InlineItemsBuilder makes at block edges and forced
//!   breaks (soft wraps hang their spaces and remove nothing, so no line
//!   breaking is needed);
//! - a block's height (Blink's LogicalHeight() in IsVisuallyEquivalent-
//!   Candidate): it has rendered content with height, or it is a root
//!   editable element (LayoutBlock::HasLineIfEmpty).
//!   TODO(renderer): a block with no content but a specified size, and an
//!   empty inline-block with padding or a border, have a height only a
//!   renderer can answer; both count as empty here.
//! Bidi (visual left/right) needs the renderer's bidi levels: "left" and
//! "right" move logically, as Blink does in an LTR block.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const infra = @import("infra");
const editing = @import("common.zig");
const word_navigation = @import("../word_navigation.zig");
const Instance = runtime.Instance;

/// A DOM boundary point, as the Selection API stores it.
pub const Point = editing.Point;

/// Blink's PositionAnchorType.
const AnchorType = enum { offset_in_anchor, before_anchor, after_anchor, after_children };

/// Blink's Position (position.h): an anchor node, and an offset in it or a
/// side of it.
const Position = struct {
    anchor: ?*Instance = null,
    offset: u32 = 0,
    type: AnchorType = .offset_in_anchor,

    const none: Position = .{};

    fn at(node: *Instance, offset: u32) Position {
        return .{ .anchor = node, .offset = offset };
    }
    fn before(node: *Instance) Position {
        return .{ .anchor = node, .type = .before_anchor };
    }
    fn after(node: *Instance) Position {
        return .{ .anchor = node, .type = .after_anchor };
    }
    fn isNull(self: Position) bool {
        return self.anchor == null;
    }
    /// Position::operator==: the same anchor, type and (for an offset in
    /// the anchor) offset.
    fn eql(a: Position, b: Position) bool {
        if (a.anchor == null) return b.anchor == null;
        if (a.anchor != b.anchor or a.type != b.type) return false;
        if (a.type != .offset_in_anchor) return true;
        return a.offset == b.offset;
    }
    fn isAfterAnchorOrAfterChildren(self: Position) bool {
        return self.type == .after_anchor or self.type == .after_children;
    }
};

/// Blink's EditingBoundaryCrossingRule.
const Rule = enum { can_cross, cannot_cross, can_skip_over };

// ============================================================================
// DOM reads
// ============================================================================

fn parentOf(node: *Instance) ?*Instance {
    return interfaces.Node.get_parentNode(node) catch null;
}
fn firstChildOf(node: *Instance) ?*Instance {
    return interfaces.Node.get_firstChild(node) catch null;
}
fn lastChildOf(node: *Instance) ?*Instance {
    return interfaces.Node.get_lastChild(node) catch null;
}
fn nextSiblingOf(node: *Instance) ?*Instance {
    return interfaces.Node.get_nextSibling(node) catch null;
}
fn previousSiblingOf(node: *Instance) ?*Instance {
    return interfaces.Node.get_previousSibling(node) catch null;
}
fn hasChildren(node: *Instance) bool {
    return firstChildOf(node) != null;
}
fn countChildren(node: *Instance) u32 {
    var count: u32 = 0;
    var child = firstChildOf(node);
    while (child) |c| : (child = nextSiblingOf(c)) count += 1;
    return count;
}
fn indexOf(node: *Instance) u32 {
    var index: u32 = 0;
    var current = previousSiblingOf(node);
    while (current) |c| : (current = previousSiblingOf(c)) index += 1;
    return index;
}
fn childAt(node: *Instance, index: u32) ?*Instance {
    var i: u32 = 0;
    var child = firstChildOf(node);
    while (child) |c| : (child = nextSiblingOf(c)) {
        if (i == index) return c;
        i += 1;
    }
    return null;
}
fn nodeType(node: *Instance) u16 {
    return interfaces.Node.get_nodeType(node) catch 0;
}
/// Blink's IsTextNode: a Text, CDATA sections included.
fn isTextNode(node: *Instance) bool {
    const kind = nodeType(node);
    return kind == interfaces.Node.get_TEXT_NODE() or kind == interfaces.Node.get_CDATA_SECTION_NODE();
}
fn isCharacterData(node: *Instance) bool {
    const kind = nodeType(node);
    return isTextNode(node) or kind == interfaces.Node.get_COMMENT_NODE() or kind == interfaces.Node.get_PROCESSING_INSTRUCTION_NODE();
}
fn isElement(node: *Instance) bool {
    return nodeType(node) == interfaces.Node.get_ELEMENT_NODE();
}
fn isDocumentNode(node: *Instance) bool {
    return nodeType(node) == interfaces.Node.get_DOCUMENT_NODE();
}
fn dataLength(node: *Instance) u32 {
    return interfaces.CharacterData.get_length(node) catch 0;
}
fn isHtml(node: *Instance, name: []const u8) bool {
    return editing.isHtmlElementNamed(node, name) catch false;
}
fn isHtmlIn(node: *Instance, names: []const []const u8) bool {
    return editing.isHtmlElementIn(node, names) catch false;
}
fn isInclusiveDescendantOf(node: *Instance, ancestor: *Instance) bool {
    return editing.isInclusiveDescendantOf(node, ancestor);
}
fn isDescendantOf(node: *Instance, ancestor: *Instance) bool {
    return editing.isDescendantOf(node, ancestor);
}
fn documentOf(node: *Instance) ?*Instance {
    if (isDocumentNode(node)) return node;
    return interfaces.Node.get_ownerDocument(node) catch null;
}
fn isDocumentElement(node: *Instance) bool {
    const document = documentOf(node) orelse return false;
    if (document == node) return false;
    return (interfaces.Document.get_documentElement(document) catch null) == node;
}
fn isBody(node: *Instance) bool {
    const document = documentOf(node) orelse return false;
    if (document == node) return false;
    return (interfaces.Document.get_body(document) catch null) == node;
}

/// Blink's IsEditable(node) (HasEditableStyle): inside an editable region,
/// the root editable element included.
fn isEditable(node: *Instance) bool {
    return editing.isEditableOrEditingHost(node) catch false;
}

/// Blink's LastOffsetForEditing (editing_strategy.cc).
fn lastOffsetForEditing(node: *Instance) u32 {
    if (isCharacterData(node)) return dataLength(node);
    if (hasChildren(node)) return countChildren(node);
    if (!editingIgnoresContent(node)) return 0;
    return 1;
}

/// Position::LastOffsetInNode.
fn lastOffsetInNode(node: *Instance) u32 {
    if (isCharacterData(node)) return dataLength(node);
    return countChildren(node);
}

/// Node::CanContainRangeEndPoint as Blink's elements override it: br, img,
/// progress, meter, plugins (embed, object) and an hr without children
/// hold no position; Text does; other non-elements do not. Form controls,
/// media, canvas and iframe hold their content in a UA shadow tree or a
/// child browsing context that no DOM-tree position reaches: they are
/// leaves here as well (Blink reaches them as replaced or control boxes).
fn canContainRangeEndPoint(node: *Instance) bool {
    if (isTextNode(node)) return true;
    const kind = nodeType(node);
    if (kind == interfaces.Node.get_DOCUMENT_NODE() or kind == interfaces.Node.get_DOCUMENT_FRAGMENT_NODE()) return true;
    if (!isElement(node)) return false;
    if (isHtmlIn(node, &.{ "br", "img", "progress", "meter", "embed", "object", "input", "textarea", "select", "video", "audio", "canvas", "iframe" })) return false;
    if (isHtml(node, "hr")) return hasChildren(node);
    return true;
}

/// Blink's EditingIgnoresContent (editing_utilities.cc), with
/// IsEmptyNonEditableNodeInEditable.
fn editingIgnoresContent(node: *Instance) bool {
    if (!canContainRangeEndPoint(node)) return true;
    if (hasChildren(node) or isEditable(node)) return false;
    const p = parentOf(node) orelse return false;
    return isEditable(p);
}

/// Blink's IsAtomicNode.
fn isAtomicNode(node: *Instance) bool {
    return !hasChildren(node) or editingIgnoresContent(node);
}

// ============================================================================
// Position helpers (position.cc)
// ============================================================================

fn computeEditingOffset(p: Position) u32 {
    if (p.isAfterAnchorOrAfterChildren()) return lastOffsetForEditing(p.anchor.?);
    return p.offset;
}

fn computeContainerNode(p: Position) ?*Instance {
    const anchor = p.anchor orelse return null;
    return switch (p.type) {
        .after_children, .offset_in_anchor => anchor,
        .before_anchor, .after_anchor => parentOf(anchor),
    };
}

fn computeOffsetInContainerNode(p: Position) u32 {
    const anchor = p.anchor orelse return 0;
    return switch (p.type) {
        .after_children => lastOffsetInNode(anchor),
        .offset_in_anchor => @min(p.offset, lastOffsetInNode(anchor)),
        .before_anchor => indexOf(anchor),
        .after_anchor => indexOf(anchor) + 1,
    };
}

fn toOffsetInAnchor(p: Position) Position {
    const container = computeContainerNode(p) orelse return .none;
    return Position.at(container, computeOffsetInContainerNode(p));
}

/// Position::ParentAnchoredEquivalent: the DOM boundary point a position
/// is exposed as (DOMSelection's anchor and focus).
fn parentAnchoredEquivalent(p: Position) Position {
    const anchor = p.anchor orelse return .none;
    if (p.offset == 0 and !p.isAfterAnchorOrAfterChildren()) {
        if (parentOf(anchor)) |parent| {
            if (editingIgnoresContent(anchor) or isDisplayInsideTable(anchor))
                return Position.at(parent, indexOf(anchor));
        }
        return Position.at(anchor, 0);
    }
    if (!isCharacterData(anchor) and (p.isAfterAnchorOrAfterChildren() or p.offset == countChildren(anchor)) and
        (editingIgnoresContent(anchor) or isDisplayInsideTable(anchor)) and computeContainerNode(p) != null)
    {
        if (parentOf(anchor)) |parent| return Position.at(parent, indexOf(anchor) + 1);
    }
    const container = computeContainerNode(p) orelse return .none;
    return Position.at(container, computeOffsetInContainerNode(p));
}

fn atFirstEditingPositionForNode(p: Position) bool {
    const anchor = p.anchor orelse return true;
    return switch (p.type) {
        .offset_in_anchor => p.offset == 0,
        .before_anchor => true,
        .after_children, .after_anchor => lastOffsetForEditing(anchor) == 0,
    };
}

fn atLastEditingPositionForNode(p: Position) bool {
    const anchor = p.anchor orelse return true;
    return p.isAfterAnchorOrAfterChildren() or p.offset >= lastOffsetForEditing(anchor);
}

/// Position::ComputeNodeBeforePosition.
fn computeNodeBeforePosition(p: Position) ?*Instance {
    const anchor = p.anchor orelse return null;
    return switch (p.type) {
        .after_children => lastChildOf(anchor),
        .offset_in_anchor => if (p.offset > 0) childAt(anchor, p.offset - 1) else null,
        .before_anchor => previousSiblingOf(anchor),
        .after_anchor => anchor,
    };
}

fn atStartOfTree(p: Position) bool {
    const anchor = p.anchor orelse return true;
    return parentOf(anchor) == null and computeNodeBeforePosition(p) == null;
}

fn lastPositionInNode(node: *Instance) Position {
    if (isTextNode(node)) return Position.at(node, lastOffsetInNode(node));
    return .{ .anchor = node, .type = .after_children };
}

fn lastPositionInOrAfterNode(node: *Instance) Position {
    if (editingIgnoresContent(node) and parentOf(node) != null) return Position.after(node);
    return lastPositionInNode(node);
}

/// Position::EditingPositionOf.
fn editingPositionOf(node: *Instance, offset: u32) Position {
    if (isTextNode(node) or !editingIgnoresContent(node)) return Position.at(node, offset);
    return if (offset == 0) Position.before(node) else Position.after(node);
}

/// Position::CompareTo: tree order of the two DOM boundary points.
fn compare(a: Position, b: Position) editing.PointOrder {
    const pa = toOffsetInAnchor(a);
    const pb = toOffsetInAnchor(b);
    const na = pa.anchor orelse return .equal;
    const nb = pb.anchor orelse return .equal;
    return editing.comparePoints(.{ .node = na, .offset = pa.offset }, .{ .node = nb, .offset = pb.offset }) catch .equal;
}

// ============================================================================
// Editability (editing_utilities.cc)
// ============================================================================

/// RootEditableElement(node).
fn rootEditableElement(node: *Instance) ?*Instance {
    var result: ?*Instance = null;
    var current: ?*Instance = node;
    while (current) |n| : (current = parentOf(n)) {
        if (!isEditable(n)) break;
        if (isElement(n)) result = n;
        if (isBody(n)) break;
    }
    return result;
}

fn rootEditableElementOf(p: Position) ?*Instance {
    var node = computeContainerNode(p) orelse return null;
    if (isDisplayInsideTable(node)) node = parentOf(node) orelse return null;
    return rootEditableElement(node);
}

fn highestEditableRoot(p: Position) ?*Instance {
    if (p.isNull()) return null;
    var highest = rootEditableElementOf(p) orelse return null;
    if (isHtml(highest, "body")) return highest;
    var node = parentOf(highest);
    while (node) |n| : (node = parentOf(n)) {
        if (isEditable(n)) highest = n;
        if (isHtml(n, "body")) break;
    }
    return highest;
}

fn isEditablePosition(p: Position) bool {
    var node = computeContainerNode(p) orelse return false;
    if (isDisplayInsideTable(node)) node = parentOf(node) orelse return false;
    if (isDocumentNode(node)) return false;
    return isEditable(node);
}

/// IsRootEditableElement: the element whose line exists even when empty
/// (LayoutBlock::HasLineIfEmpty).
fn isRootEditableElement(node: *Instance) bool {
    if (!isEditable(node) or !isElement(node)) return false;
    const p = parentOf(node) orelse return true;
    return !isEditable(p) or !isElement(p) or isBody(node);
}

// ============================================================================
// Layout facts, from the style system
// ============================================================================

const Box = enum {
    /// No layout object (display: none, not in the flat tree, a child of a
    /// replaced element, display: contents).
    none,
    /// LayoutInline: display inline (flow).
    inline_flow,
    /// An atomic inline: inline-block, inline-flex, inline-grid, inline-
    /// table, or a replaced element laid out inline.
    atomic_inline,
    /// A block-level block container, flex or grid box, a table cell or
    /// caption (LayoutBlockFlow, LayoutFlexibleBox, LayoutGrid).
    block,
    /// Another box: a table and its rows, sections and columns, a block-
    /// level replaced element.
    other,
};

const replaced_names = [_][]const u8{ "img", "input", "textarea", "select", "video", "audio", "canvas", "iframe", "embed", "object", "meter", "progress" };

fn computedStyleOf(element: *Instance) ?*const @import("css").computed_style.ComputedStyle {
    return dom.style.computedStyle(element, null) catch null;
}

/// Whether `node` sits inside a replaced element, whose DOM children
/// produce no boxes.
fn insideReplaced(node: *Instance) bool {
    var current = parentOf(node);
    while (current) |n| : (current = parentOf(n)) {
        if (isElement(n) and isHtmlIn(n, &replaced_names)) return true;
    }
    return false;
}

/// The selectable and visible bits of a layout object's style.
const StyleBits = struct { visible: bool, selectable: bool };

/// The context of one Selection.modify: its scratch arena and the layout
/// facts it has read, which no DOM change can invalidate while it runs.
pub const Context = struct {
    arena_state: std.heap.ArenaAllocator,
    boxes: std.AutoHashMapUnmanaged(*Instance, Box) = .empty,
    texts: std.AutoHashMapUnmanaged(*Instance, *TextInfo) = .empty,
    inlines: std.AutoHashMapUnmanaged(*Instance, *InlineRoot) = .empty,

    pub fn init(allocator: std.mem.Allocator) Context {
        return .{ .arena_state = std.heap.ArenaAllocator.init(allocator) };
    }

    pub fn deinit(self: *Context) void {
        self.arena_state.deinit();
    }

    fn arena(self: *Context) std.mem.Allocator {
        return self.arena_state.allocator();
    }

    // ------------------------------------------------------------------
    // Boxes
    // ------------------------------------------------------------------

    /// The box `element` generates (Blink's GetLayoutObject and its type).
    fn boxOf(self: *Context, element: *Instance) Box {
        if (self.boxes.get(element)) |box| return box;
        const box = computeBox(element);
        self.boxes.put(self.arena(), element, box) catch {};
        return box;
    }

    fn computeBox(element: *Instance) Box {
        if (!isElement(element)) return .none;
        if (!(dom.style.isBeingRendered(element) catch false)) return .none;
        if (insideReplaced(element)) return .none;
        const style = computedStyleOf(element) orelse return .none;
        const display = style.display();
        const replaced = isHtmlIn(element, &replaced_names);
        switch (display.box) {
            .none, .contents => return .none,
            .internal => return switch (display.internal) {
                .table_cell, .table_caption => .block,
                else => .other,
            },
            .normal => {},
        }
        if (display.outer == .inline_) {
            if (!replaced and (display.inner == .flow or display.inner == .ruby)) return .inline_flow;
            return .atomic_inline;
        }
        if (replaced or display.inner == .table) return .other;
        return .block;
    }

    /// Whether `node` has a layout object.
    fn hasLayoutObject(self: *Context, node: *Instance) bool {
        if (isTextNode(node)) return self.textInfo(node).has_layout;
        return self.boxOf(node) != .none;
    }

    /// LayoutObject::IsInline: an inline-level box, a Text, a br.
    fn isInlineLevel(self: *Context, node: *Instance) bool {
        if (isTextNode(node)) return true;
        return switch (self.boxOf(node)) {
            .inline_flow, .atomic_inline => true,
            else => false,
        };
    }

    fn styleBits(node: *Instance) StyleBits {
        const element = if (isElement(node)) node else (parentOf(node) orelse return .{ .visible = false, .selectable = false });
        if (!isElement(element)) return .{ .visible = true, .selectable = true };
        const style = computedStyleOf(element) orelse return .{ .visible = false, .selectable = false };
        // LayoutObject::IsSelectable: user-select: none on a read-only
        // node is not selectable; an editable one still is.
        const selectable = style.keyword(.user_select) != .none or isEditable(node);
        return .{ .visible = style.keyword(.visibility) == .visible, .selectable = selectable };
    }

    /// Blink's EndsOfNodeAreVisuallyDistinctPositions.
    fn endsOfNodeAreVisuallyDistinctPositions(self: *Context, node: *Instance) bool {
        if (!self.hasLayoutObject(node)) return false;
        if (!self.isInlineLevel(node)) return true;
        if (isHtml(node, "table")) return false;
        if (isHtml(node, "marquee")) return true;
        // An atomic inline with a size and no content holds a position of
        // its own (an empty inline-block). TODO(renderer): its size is a
        // renderer read (LayoutBox::StitchedSize); none is known here.
        return false;
    }

    /// Blink's HasRenderedNonAnonymousDescendantsWithHeight: rendered Text
    /// that is not all collapsed, a br, or a replaced box.
    fn hasRenderedDescendantsWithHeight(self: *Context, root: *Instance) bool {
        var current = firstChildOf(root);
        while (current) |node| {
            var descend = true;
            if (isTextNode(node)) {
                const info = self.textInfo(node);
                if (info.has_layout and info.hasNonCollapsedText()) return true;
            } else if (isElement(node)) {
                const box = self.boxOf(node);
                if (box == .none) {
                    // display: contents keeps its children's boxes.
                    descend = isDisplayContents(node);
                } else if (isHtml(node, "br") or isHtmlIn(node, &replaced_names)) {
                    return true;
                } else if (isRootEditableElement(node)) {
                    return true;
                }
            } else descend = false;
            current = if (descend) (firstChildOf(node) orelse nextInside(node, root)) else nextInside(node, root);
        }
        return false;
    }

    /// LayoutBlock::LogicalHeight() != 0, without a renderer: content with
    /// height, or a root editable element's line.
    fn blockHasHeight(self: *Context, block: *Instance) bool {
        return isRootEditableElement(block) or self.hasRenderedDescendantsWithHeight(block);
    }

    // ------------------------------------------------------------------
    // Text
    // ------------------------------------------------------------------

    /// The layout facts of the Text `node`: its UTF-16 data and which of
    /// its code units are not collapsed.
    fn textInfo(self: *Context, node: *Instance) *const TextInfo {
        if (self.texts.get(node)) |info| return info;
        // The inline formatting context decides collapsing: lay it out
        // whole, which records every Text in it.
        if (self.ifcRootOf(node)) |root| _ = self.inlineRoot(root);
        if (self.texts.get(node)) |info| return info;
        return self.unrenderedText(node);
    }

    fn unrenderedText(self: *Context, node: *Instance) *const TextInfo {
        const info = self.arena().create(TextInfo) catch return &TextInfo.empty;
        const units = decodeUnits(self.arena(), node);
        info.* = .{ .units = units, .rendered = &.{}, .has_layout = false, .boundaries = graphemeBoundaries(self.arena(), node, units.len) };
        self.texts.put(self.arena(), node, info) catch {};
        return info;
    }

    // ------------------------------------------------------------------
    // Inline formatting contexts
    // ------------------------------------------------------------------

    /// The block container whose inline formatting context `node` is laid
    /// out in: its nearest ancestor box that is not an inline box.
    fn ifcRootOf(self: *Context, node: *Instance) ?*Instance {
        var current = parentOf(node);
        while (current) |n| : (current = parentOf(n)) {
            if (!isElement(n)) return null;
            switch (self.boxOf(n)) {
                .inline_flow => continue,
                .none => {
                    if (isDisplayContents(n)) continue;
                    return null;
                },
                else => return n,
            }
        }
        return null;
    }

    fn inlineRoot(self: *Context, root: *Instance) *const InlineRoot {
        if (self.inlines.get(root)) |r| return r;
        const result = self.arena().create(InlineRoot) catch return &InlineRoot.empty;
        result.* = InlineBuilder.build(self, root) catch InlineRoot.empty;
        self.inlines.put(self.arena(), root, result) catch {};
        return result;
    }
};

fn isDisplayContents(element: *Instance) bool {
    const style = computedStyleOf(element) orelse return false;
    return style.display().box == .contents;
}

fn isDisplayInsideTable(node: *Instance) bool {
    if (!isElement(node)) return false;
    const style = computedStyleOf(node) orelse return false;
    const display = style.display();
    return display.box == .normal and display.inner == .table;
}

fn isOutOfFlow(element: *Instance) bool {
    const style = computedStyleOf(element) orelse return false;
    const position = style.keyword(.position);
    return style.keyword(.float) != .none or position == .absolute or position == .fixed;
}

/// The next node after `node` in tree order inside `root`, skipping
/// `node`'s children.
fn nextInside(node: *Instance, root: *Instance) ?*Instance {
    var current = node;
    while (current != root) {
        if (nextSiblingOf(current)) |sibling| return sibling;
        current = parentOf(current) orelse return null;
    }
    return null;
}

fn decodeUnits(allocator: std.mem.Allocator, node: *Instance) []const u16 {
    const data = dom.character_data.dataOf(node) orelse return &.{};
    const units = std.unicode.wtf8ToWtf16LeAlloc(allocator, data) catch return &.{};
    for (units) |*unit| unit.* = std.mem.littleToNative(u16, unit.*);
    return units;
}

/// A Text's layout facts.
const TextInfo = struct {
    units: []const u16,
    /// Per code unit: not collapsed. Empty without a layout object.
    rendered: []const bool,
    has_layout: bool,
    /// Per offset 0..len: a grapheme cluster boundary.
    boundaries: []const bool = &.{},

    const empty: TextInfo = .{ .units = &.{}, .rendered = &.{}, .has_layout = false };

    fn boundaryAt(self: *const TextInfo, offset: u32) bool {
        if (offset == 0 or offset >= self.len()) return true;
        return offset >= self.boundaries.len or self.boundaries[offset];
    }
    /// NextGraphemeBoundaryOf.
    fn nextGraphemeBoundary(self: *const TextInfo, offset: u32) u32 {
        var at = offset + 1;
        while (at < self.len() and !self.boundaryAt(at)) at += 1;
        return @min(at, self.len());
    }
    /// PreviousGraphemeBoundaryOf.
    fn previousGraphemeBoundary(self: *const TextInfo, offset: u32) u32 {
        if (offset == 0) return 0;
        var at = offset - 1;
        while (at > 0 and !self.boundaryAt(at)) at -= 1;
        return at;
    }

    fn len(self: *const TextInfo) u32 {
        return @intCast(self.units.len);
    }
    fn isRendered(self: *const TextInfo, index: u32) bool {
        return index < self.rendered.len and self.rendered[index];
    }
    fn hasNonCollapsedText(self: *const TextInfo) bool {
        for (self.rendered) |r| if (r) return true;
        return false;
    }
    /// LayoutText::IsBeforeNonCollapsedCharacter.
    fn isBeforeNonCollapsedCharacter(self: *const TextInfo, offset: u32) bool {
        return self.isRendered(offset);
    }
    /// LayoutText::IsAfterNonCollapsedCharacter.
    fn isAfterNonCollapsedCharacter(self: *const TextInfo, offset: u32) bool {
        return offset > 0 and self.isRendered(offset - 1);
    }
    /// LayoutText::ContainsCaretOffset: before a rendered character, or
    /// after one that is not a forced line break.
    fn containsCaretOffset(self: *const TextInfo, offset: u32) bool {
        if (offset > self.len()) return false;
        if (self.isBeforeNonCollapsedCharacter(offset)) return true;
        if (!self.isAfterNonCollapsedCharacter(offset)) return false;
        return self.units[offset - 1] != '\n';
    }
    /// LayoutText::CaretMinOffset.
    fn caretMinOffset(self: *const TextInfo) u32 {
        for (self.rendered, 0..) |r, i| if (r) return @intCast(i);
        return 0;
    }
    /// LayoutText::CaretMaxOffset.
    fn caretMaxOffset(self: *const TextInfo) u32 {
        var i: usize = self.rendered.len;
        while (i > 0) : (i -= 1) if (self.rendered[i - 1]) return @intCast(i);
        return self.len();
    }
    /// Whether `offset` is a grapheme cluster boundary (UAX #29).
    fn isGraphemeBoundary(self: *const TextInfo, offset: u32) bool {
        return self.boundaryAt(offset);
    }
};

/// One unit of an inline formatting context's text content (Blink's
/// OffsetMapping): a rendered code unit of a Text, an atomic inline as
/// U+FFFC, or a forced break as a line feed.
const Unit = struct {
    node: *Instance,
    /// The DOM offset of the code unit in its Text.
    offset: u32 = 0,
    kind: enum { text, object, line_break },
};

/// One inline formatting context: a run of inline content between block
/// boundaries (Blink's InlineContents / TextOffsetMapping).
const Segment = struct {
    units: []const Unit,
    text: []const u16,
};

const InlineRoot = struct {
    segments: []const Segment,
    const empty: InlineRoot = .{ .segments = &.{} };
};

/// CSS Text 3 section 4.1.1 over an inline formatting context, as Blink's
/// InlineItemsBuilder collapses it: a collapsible space after another
/// (across inline element edges) or at a line start (the context's start,
/// after a forced break) collapses; one before a forced break or the end
/// of the context is removed; an atomic inline is a non-space; out-of-flow
/// boxes take no part.
const InlineBuilder = struct {
    ctx: *Context,
    segments: std.ArrayList(Segment) = .empty,
    units: std.ArrayList(Unit) = .empty,
    text: std.ArrayList(u16) = .empty,
    after_space: bool = true,
    /// The flag of the last rendered collapsible space, while nothing has
    /// followed it on its line.
    trailing: ?*bool = null,

    fn build(ctx: *Context, root: *Instance) !InlineRoot {
        var self = InlineBuilder{ .ctx = ctx };
        const a = ctx.arena();
        var current = firstChildOf(root);
        while (current) |node| {
            var descend = false;
            if (isTextNode(node)) {
                try self.addText(node);
            } else if (isElement(node)) {
                switch (ctx.boxOf(node)) {
                    .none => descend = isDisplayContents(node),
                    .inline_flow => {
                        if (isHtml(node, "br")) {
                            try self.forcedBreak(node);
                        } else descend = true;
                    },
                    .atomic_inline => {
                        if (isOutOfFlow(node)) {} else if (isHtml(node, "br")) try self.forcedBreak(node) else try self.object(node);
                    },
                    .block, .other => {
                        if (!isOutOfFlow(node)) try self.endSegment();
                    },
                }
            }
            current = if (descend) (firstChildOf(node) orelse nextInside(node, root)) else nextInside(node, root);
        }
        try self.endSegment();
        return .{ .segments = try self.segments.toOwnedSlice(a) };
    }

    fn removeTrailing(self: *InlineBuilder) void {
        if (self.trailing) |flag| {
            flag.* = false;
            _ = self.units.pop();
            _ = self.text.pop();
        }
        self.trailing = null;
    }

    fn render(self: *InlineBuilder, unit: Unit, char: u16) !void {
        const a = self.ctx.arena();
        try self.units.append(a, unit);
        try self.text.append(a, char);
    }

    fn endSegment(self: *InlineBuilder) !void {
        self.removeTrailing();
        const a = self.ctx.arena();
        if (self.units.items.len > 0) {
            try self.segments.append(a, .{ .units = try self.units.toOwnedSlice(a), .text = try self.text.toOwnedSlice(a) });
        }
        self.units = .empty;
        self.text = .empty;
        self.after_space = true;
    }

    fn forcedBreak(self: *InlineBuilder, br: *Instance) !void {
        self.removeTrailing();
        try self.render(.{ .node = br, .kind = .line_break }, '\n');
        self.after_space = true;
    }

    fn object(self: *InlineBuilder, element: *Instance) !void {
        self.trailing = null;
        try self.render(.{ .node = element, .kind = .object }, 0xFFFC);
        self.after_space = false;
    }

    fn addText(self: *InlineBuilder, node: *Instance) !void {
        const a = self.ctx.arena();
        const units = decodeUnits(a, node);
        const info = try a.create(TextInfo);
        const rendered = try a.alloc(bool, units.len);
        @memset(rendered, false);
        info.* = .{ .units = units, .rendered = rendered, .has_layout = false, .boundaries = graphemeBoundaries(a, node, units.len) };
        try self.ctx.texts.put(a, node, info);
        const parent = parentOf(node) orelse return;
        if (!isElement(parent)) return;
        if (!(dom.style.engine.isBeingRenderedOrDelegating(parent) catch false) or insideReplaced(node)) return;
        if (units.len == 0) return;
        const white_space = editing.whiteSpaceOf(parent);
        info.has_layout = self.textLayoutObjectIsNeeded(node, units, white_space);
        if (!info.has_layout) return;
        const collapses = !white_space.preservesSpaces();
        const keeps_breaks = white_space.preservesNewlines();
        for (units, 0..) |unit, i| {
            const offset: u32 = @intCast(i);
            if (unit == '\n' and keeps_breaks) {
                // A preserved segment break is a forced line break.
                self.removeTrailing();
                rendered[i] = true;
                try self.render(.{ .node = node, .offset = offset, .kind = .text }, '\n');
                self.after_space = true;
                continue;
            }
            const space = unit == ' ' or unit == '\t' or unit == '\n' or unit == '\r';
            if (collapses and space) {
                if (self.after_space) continue;
                rendered[i] = true;
                try self.render(.{ .node = node, .offset = offset, .kind = .text }, ' ');
                self.after_space = true;
                self.trailing = &rendered[i];
                continue;
            }
            rendered[i] = true;
            try self.render(.{ .node = node, .offset = offset, .kind = .text }, unit);
            self.after_space = false;
            self.trailing = null;
        }
    }

    /// Blink's Text::TextLayoutObjectIsNeeded: white-space-only text gets
    /// no layout object unless white-space keeps its breaks, or it follows
    /// inline content that does not end in white-space.
    fn textLayoutObjectIsNeeded(self: *InlineBuilder, node: *Instance, units: []const u16, white_space: editing.WhiteSpace) bool {
        for (units) |unit| switch (unit) {
            ' ', '\t', '\n', '\r', 0x0c => {},
            else => return true,
        };
        if (white_space.preservesNewlines()) return true;
        const previous = self.previousInFlow(node) orelse {
            // No previous sibling box: only inside an inline box.
            var parent = parentOf(node);
            while (parent) |p| : (parent = parentOf(p)) {
                if (!isElement(p) or !isDisplayContents(p)) break;
            }
            const p = parent orelse return false;
            return isElement(p) and self.ctx.boxOf(p) == .inline_flow;
        };
        if (isTextNode(previous)) {
            const info = self.ctx.texts.get(previous) orelse return true;
            if (info.units.len == 0) return true;
            return switch (info.units[info.units.len - 1]) {
                ' ', '\t', '\n', '\r', 0x0c => false,
                else => true,
            };
        }
        return self.ctx.isInlineLevel(previous) and !isHtml(previous, "br");
    }

    /// The previous in-flow sibling box of `node` (Blink's AttachContext
    /// previous_in_flow): Text with a layout object, or an element box;
    /// display: contents is looked through, out-of-flow boxes are not in
    /// flow.
    fn previousInFlow(self: *InlineBuilder, node: *Instance) ?*Instance {
        var current = node;
        while (true) {
            var sibling = previousSiblingOf(current);
            while (sibling) |s| : (sibling = previousSiblingOf(s)) {
                if (self.lastInFlowOf(s)) |found| return found;
            }
            const p = parentOf(current) orelse return null;
            if (!isElement(p) or !isDisplayContents(p)) return null;
            current = p;
        }
    }

    fn lastInFlowOf(self: *InlineBuilder, node: *Instance) ?*Instance {
        if (isTextNode(node)) {
            const info = self.ctx.texts.get(node) orelse return null;
            return if (info.has_layout) node else null;
        }
        if (!isElement(node)) return null;
        if (self.ctx.boxOf(node) == .none) {
            if (!isDisplayContents(node)) return null;
            var child = lastChildOf(node);
            while (child) |c| : (child = previousSiblingOf(c)) {
                if (self.lastInFlowOf(c)) |found| return found;
            }
            return null;
        }
        if (isOutOfFlow(node)) return null;
        return node;
    }
};

/// Per UTF-16 offset 0..len of a Text, whether it is a grapheme cluster
/// boundary (the intl module's UAX #29 iterator).
fn graphemeBoundaries(allocator: std.mem.Allocator, node: *Instance, len: usize) []const bool {
    const boundaries = allocator.alloc(bool, len + 1) catch return &.{};
    @memset(boundaries, false);
    boundaries[0] = true;
    boundaries[len] = true;
    const bytes = dom.character_data.dataOf(node) orelse return boundaries;
    var iterator = @import("intl").segmenter.GraphemeIterator.init(bytes);
    var at: usize = 0;
    while (iterator.next()) |cluster| {
        at += infra.wtf8.codeUnitLength(cluster);
        if (at <= len) boundaries[at] = true;
    }
    return boundaries;
}

fn appendWtf8(allocator: std.mem.Allocator, list: *std.ArrayList(u8), units: []const u16) !void {
    var i: usize = 0;
    while (i < units.len) : (i += 1) {
        var cp: u21 = units[i];
        if (std.unicode.utf16IsHighSurrogate(units[i]) and i + 1 < units.len and std.unicode.utf16IsLowSurrogate(units[i + 1])) {
            cp = 0x10000 + ((@as(u21, units[i]) - 0xD800) << 10) + (units[i + 1] - 0xDC00);
            i += 1;
        }
        var buf: [4]u8 = undefined;
        const n = std.unicode.wtf8Encode(cp, &buf) catch return error.InvalidWtf8;
        try list.appendSlice(allocator, buf[0..n]);
    }
}

// ============================================================================
// PositionIterator (position_iterator.cc, the slow algorithm)
// ============================================================================

const Iterator = struct {
    ctx: *Context,
    anchor: ?*Instance,
    /// The node after the position in the anchor.
    child: ?*Instance,
    /// The offset in a leaf anchor, or the child's index.
    offset: u32,

    fn init(ctx: *Context, p: Position) Iterator {
        const anchor = p.anchor orelse return .{ .ctx = ctx, .anchor = null, .child = null, .offset = 0 };
        const editing_offset = computeEditingOffset(p);
        const child = childAt(anchor, editing_offset);
        return .{ .ctx = ctx, .anchor = anchor, .child = child, .offset = editing_offset };
    }

    fn node(self: Iterator) ?*Instance {
        return self.anchor;
    }

    fn computePosition(self: Iterator) Position {
        const anchor = self.anchor orelse return .none;
        if (self.child != null) return Position.at(anchor, self.offset);
        if (hasChildren(anchor)) return lastPositionInOrAfterNode(anchor);
        if (isTextNode(anchor)) return Position.at(anchor, self.offset);
        return if (self.offset != 0) Position.after(anchor) else Position.before(anchor);
    }

    fn deprecatedComputePosition(self: Iterator) Position {
        const anchor = self.anchor orelse return .none;
        if (self.child != null) {
            if (editingIgnoresContent(anchor)) return Position.before(anchor);
            return Position.at(anchor, self.offset);
        }
        if (hasChildren(anchor)) return lastPositionInOrAfterNode(anchor);
        return editingPositionOf(anchor, self.offset);
    }

    fn increment(self: *Iterator) void {
        const anchor = self.anchor orelse return;
        if (self.child) |child| {
            // Case 1: into the child, before its first child.
            self.anchor = child;
            self.child = firstChildOf(child);
            self.offset = 0;
            return;
        }
        if (self.ctx.hasLayoutObject(anchor) and !hasChildren(anchor) and self.offset < lastOffsetForEditing(anchor)) {
            // Case 2: the next grapheme boundary in a leaf.
            self.offset = self.nextBoundary(anchor, self.offset);
            return;
        }
        // Case 3: out of the anchor, after it in its parent.
        const parent = parentOf(anchor) orelse {
            self.child = anchor;
            self.anchor = null;
            return;
        };
        self.offset = indexOf(anchor) + 1;
        self.child = nextSiblingOf(anchor);
        self.anchor = parent;
    }

    fn decrement(self: *Iterator) void {
        const anchor = self.anchor orelse return;
        if (self.child) |child| {
            if (previousSiblingOf(child)) |previous| {
                // Case 1-a: to the end of the previous sibling.
                self.anchor = previous;
                self.child = null;
                self.offset = if (hasChildren(previous)) countChildren(previous) else lastOffsetForEditing(previous);
                return;
            }
            // Case 1-b: out of the anchor, before it in its parent.
            const parent = parentOf(anchor) orelse {
                self.child = anchor;
                self.anchor = null;
                return;
            };
            self.child = anchor;
            self.anchor = parent;
            self.offset = indexOf(anchor);
            return;
        }
        if (hasChildren(anchor)) {
            // Case 2: from the end of a container to its last child's end.
            const last = lastChildOf(anchor).?;
            self.anchor = last;
            self.offset = if (hasChildren(last)) countChildren(last) else lastOffsetForEditing(last);
            return;
        }
        if (self.offset != 0 and self.ctx.hasLayoutObject(anchor)) {
            // Case 3-a: the previous grapheme boundary in a leaf.
            self.offset = self.previousBoundary(anchor, self.offset);
            return;
        }
        // Case 3-b: out of the leaf, before it in its parent.
        const parent = parentOf(anchor) orelse {
            self.child = anchor;
            self.anchor = null;
            return;
        };
        self.child = anchor;
        self.anchor = parent;
        self.offset = indexOf(anchor);
    }

    fn nextBoundary(self: Iterator, anchor: *Instance, offset: u32) u32 {
        if (!isTextNode(anchor)) return offset + 1;
        return self.ctx.textInfo(anchor).nextGraphemeBoundary(offset);
    }

    fn previousBoundary(self: Iterator, anchor: *Instance, offset: u32) u32 {
        if (!isTextNode(anchor)) return offset - 1;
        return self.ctx.textInfo(anchor).previousGraphemeBoundary(offset);
    }

    fn atStart(self: Iterator) bool {
        const anchor = self.anchor orelse return true;
        if (parentOf(anchor) != null) return false;
        if (self.child) |child| return previousSiblingOf(child) == null;
        return !hasChildren(anchor) and self.offset == 0;
    }

    fn atEnd(self: Iterator) bool {
        const anchor = self.anchor orelse return true;
        if (self.child != null) return false;
        return parentOf(anchor) == null and (hasChildren(anchor) or self.offset >= lastOffsetForEditing(anchor));
    }

    fn atStartOfNode(self: Iterator) bool {
        const anchor = self.anchor orelse return true;
        if (self.child) |child| return previousSiblingOf(child) == null;
        return !hasChildren(anchor) and self.offset == 0;
    }

    fn atEndOfNode(self: Iterator) bool {
        const anchor = self.anchor orelse return true;
        if (self.child != null) return false;
        return hasChildren(anchor) or self.offset >= lastOffsetForEditing(anchor);
    }

    /// IsStreamer (visible_units.cc).
    fn isStreamer(self: Iterator) bool {
        const anchor = self.anchor orelse return true;
        if (isAtomicNode(anchor)) return true;
        return self.atStartOfNode();
    }
};

// ============================================================================
// Candidates (visible_units.cc)
// ============================================================================

/// Blink's EnclosingVisualBoundary.
fn enclosingVisualBoundary(ctx: *Context, node: *Instance) ?*Instance {
    var current: ?*Instance = node;
    while (current) |n| : (current = parentOf(n)) {
        if (ctx.endsOfNodeAreVisuallyDistinctPositions(n)) return n;
    }
    return null;
}

/// Blink's MostBackwardCaretPosition (in the DOM tree; no shadow
/// adjustment).
fn mostBackwardCaretPosition(ctx: *Context, position: Position, rule: Rule) Position {
    const start_node = position.anchor orelse return .none;
    const boundary = enclosingVisualBoundary(ctx, start_node);
    // AdjustPositionForBackwardIteration.
    const adjusted = if (position.type == .after_anchor)
        editingPositionOf(start_node, caretMaxOffset(ctx, start_node))
    else
        position;
    var last_visible = Iterator.init(ctx, adjusted);
    var last_node: *Instance = start_node;
    const start_editable = isEditable(last_node);
    var boundary_crossed = false;
    var current = last_visible;
    while (!current.atStart()) : (current.decrement()) {
        const node = current.node() orelse break;
        if (node != last_node) {
            if (isEditable(node) != start_editable) {
                if (rule == .cannot_cross) break;
                boundary_crossed = true;
            }
            last_node = node;
        }
        // A position that is visually distinct: return the last kept one.
        if (ctx.endsOfNodeAreVisuallyDistinctPositions(node) and node != boundary)
            return last_visible.deprecatedComputePosition();
        // Skip positions in a node without a layout object, or invisible.
        if (!ctx.hasLayoutObject(node) or !Context.styleBits(node).visible) {
            if (boundary_crossed and rule == .cannot_cross) break;
            continue;
        }
        if (boundary_crossed) {
            if (rule == .cannot_cross) {
                if (node == start_node) return position;
                return Position.after(node);
            }
            if (rule == .can_cross) {
                last_visible = current;
                break;
            }
        }
        if (current.isStreamer()) last_visible = current;
        if (ctx.endsOfNodeAreVisuallyDistinctPositions(node) and current.atStartOfNode())
            return last_visible.deprecatedComputePosition();
        if (editingIgnoresContent(node) or isDisplayInsideTable(node)) {
            if (current.atEndOfNode()) return Position.after(node);
            continue;
        }
        if (!isTextNode(node)) continue;
        const info = ctx.textInfo(node);
        if (!info.hasNonCollapsedText()) continue;
        if (node != start_node) return Position.at(node, info.caretMaxOffset());
        if (info.isAfterNonCollapsedCharacter(current.offset)) return current.computePosition();
    }
    return last_visible.deprecatedComputePosition();
}

/// Blink's MostForwardCaretPosition (in the DOM tree).
fn mostForwardCaretPosition(ctx: *Context, position: Position, rule: Rule) Position {
    const start_node = position.anchor orelse return .none;
    const boundary = enclosingVisualBoundary(ctx, start_node);
    var last_visible = Iterator.init(ctx, if (position.type == .after_anchor)
        editingPositionOf(start_node, caretMaxOffset(ctx, start_node))
    else
        position);
    var last_node: *Instance = start_node;
    const start_editable = isEditable(last_node);
    var boundary_crossed = false;
    var current = last_visible;
    while (!current.atEnd()) : (current.increment()) {
        const node = current.node() orelse break;
        if (node != last_node) {
            if (isEditable(node) != start_editable) {
                if (rule == .cannot_cross) break;
                boundary_crossed = true;
            }
            last_node = node;
        }
        // Stop before going above the body, up into the head.
        if (isHtml(node, "body") and current.atEndOfNode()) break;
        if (ctx.endsOfNodeAreVisuallyDistinctPositions(node) and node != boundary)
            return last_visible.deprecatedComputePosition();
        if (boundary) |b| if (parentOf(b) == node) return last_visible.deprecatedComputePosition();
        if (!ctx.hasLayoutObject(node) or !Context.styleBits(node).visible) {
            if (boundary_crossed and rule == .cannot_cross) break;
            continue;
        }
        if (boundary_crossed) {
            if (rule == .cannot_cross) {
                if (node == start_node) return position;
                return Position.before(node);
            }
            if (rule == .can_cross) return current.deprecatedComputePosition();
        }
        if (current.isStreamer()) last_visible = current;
        if (editingIgnoresContent(node) or isDisplayInsideTable(node)) {
            if (current.atStartOfNode()) return editingPositionOf(node, 0);
            continue;
        }
        if (!isTextNode(node)) continue;
        const info = ctx.textInfo(node);
        if (!info.hasNonCollapsedText()) continue;
        if (node != start_node) return Position.at(node, info.caretMinOffset());
        if (info.isBeforeNonCollapsedCharacter(current.offset)) return current.computePosition();
    }
    return last_visible.deprecatedComputePosition();
}

/// EditingStrategy::CaretMaxOffset.
fn caretMaxOffset(ctx: *Context, node: *Instance) u32 {
    if (isTextNode(node)) {
        const info = ctx.textInfo(node);
        if (info.has_layout) return info.caretMaxOffset();
    }
    return lastOffsetForEditing(node);
}

/// InRenderedText.
fn inRenderedText(ctx: *Context, p: Position) bool {
    const anchor = p.anchor orelse return false;
    if (!isTextNode(anchor)) return false;
    const info = ctx.textInfo(anchor);
    if (!info.has_layout) return false;
    const offset = computeEditingOffset(p);
    if (!info.containsCaretOffset(offset)) return false;
    return offset == info.caretMinOffset() or info.isGraphemeBoundary(offset);
}

/// AtEditingBoundary.
fn atEditingBoundary(ctx: *Context, p: Position) bool {
    const next = mostForwardCaretPosition(ctx, p, .can_cross);
    if (atFirstEditingPositionForNode(p) and !next.isNull() and !isEditable(next.anchor.?)) return true;
    const previous = mostBackwardCaretPosition(ctx, p, .can_cross);
    if (atLastEditingPositionForNode(p) and !previous.isNull() and !isEditable(previous.anchor.?)) return true;
    return !next.isNull() and !isEditable(next.anchor.?) and !previous.isNull() and !isEditable(previous.anchor.?);
}

/// Blink's IsVisuallyEquivalentCandidate: whether a caret can be at `p`.
fn isVisuallyEquivalentCandidate(ctx: *Context, p: Position) bool {
    const anchor = p.anchor orelse return false;
    if (!ctx.hasLayoutObject(anchor)) return false;
    const bits = Context.styleBits(anchor);
    if (!bits.visible) return false;
    if (isHtml(anchor, "br")) {
        if (p.type == .after_anchor) return false;
        if (computeEditingOffset(p) != 0) return false;
        const parent = parentOf(anchor) orelse return false;
        return ctx.hasLayoutObject(parent) and Context.styleBits(parent).selectable;
    }
    if (isTextNode(anchor)) return bits.selectable and inRenderedText(ctx, p);
    if (isDisplayInsideTable(anchor) or editingIgnoresContent(anchor)) {
        if (!atFirstEditingPositionForNode(p) and !atLastEditingPositionForNode(p)) return false;
        const parent = parentOf(anchor) orelse return false;
        return ctx.hasLayoutObject(parent) and Context.styleBits(parent).selectable;
    }
    if (isDocumentElement(anchor) or isDocumentNode(anchor)) return false;
    if (!bits.selectable) return false;
    if (ctx.boxOf(anchor) == .block) {
        if (ctx.blockHasHeight(anchor) or isBody(anchor)) {
            if (!ctx.hasRenderedDescendantsWithHeight(anchor)) return atFirstEditingPositionForNode(p);
            return isEditable(anchor) and atEditingBoundary(ctx, p);
        }
        return false;
    }
    return isEditable(anchor) and atEditingBoundary(ctx, p);
}

fn canonicalizeCandidate(ctx: *Context, candidate: Position) Position {
    if (candidate.isNull()) return .none;
    const upstream = mostBackwardCaretPosition(ctx, candidate, .cannot_cross);
    if (isVisuallyEquivalentCandidate(ctx, upstream)) return upstream;
    return candidate;
}

fn nextCandidate(ctx: *Context, position: Position) Position {
    var p = Iterator.init(ctx, position);
    p.increment();
    while (!p.atEnd()) : (p.increment()) {
        const candidate = p.computePosition();
        if (isVisuallyEquivalentCandidate(ctx, candidate)) return candidate;
    }
    return .none;
}

fn previousCandidate(ctx: *Context, position: Position) Position {
    var p = Iterator.init(ctx, position);
    p.decrement();
    while (!p.atStart()) : (p.decrement()) {
        const candidate = p.computePosition();
        if (isVisuallyEquivalentCandidate(ctx, candidate)) return candidate;
    }
    return .none;
}

/// Blink's EnclosingBlockFlowElement: the nearest inclusive ancestor
/// element with a block box.
fn enclosingBlockFlowElement(ctx: *Context, node: *Instance) ?*Instance {
    var current: ?*Instance = node;
    while (current) |n| : (current = parentOf(n)) {
        if (isElement(n) and ctx.boxOf(n) == .block) return n;
    }
    return null;
}

fn inSameBlock(ctx: *Context, original: ?*Instance, new: *Instance) bool {
    const node = original orelse return false;
    if (isDescendantOf(new, node)) return true;
    const original_block = enclosingBlockFlowElement(ctx, node);
    if (isEditable(node) and isEditable(new)) {
        const block = original_block orelse return false;
        return isInclusiveDescendantOf(new, block);
    }
    return original_block == enclosingBlockFlowElement(ctx, new);
}

/// Blink's CanonicalPosition (CreateVisiblePosition's deep equivalent).
fn canonicalPosition(ctx: *Context, position: Position) Position {
    if (position.isNull()) return .none;
    const backward = mostBackwardCaretPosition(ctx, position, .cannot_cross);
    if (isVisuallyEquivalentCandidate(ctx, backward)) return backward;
    const forward = mostForwardCaretPosition(ctx, position, .cannot_cross);
    if (isVisuallyEquivalentCandidate(ctx, forward)) return forward;
    // Neither leaves its block: search for a candidate both ways.
    const next = canonicalizeCandidate(ctx, nextCandidate(ctx, position));
    const prev = canonicalizeCandidate(ctx, previousCandidate(ctx, position));
    const node = computeContainerNode(position);
    if (node) |n| {
        if (isDocumentElement(n) and !isEditable(n)) {
            if (documentOf(n)) |document| {
                if (interfaces.Document.get_body(document) catch null) |body| {
                    if (isEditable(body)) return if (!next.isNull()) next else prev;
                }
            }
        }
    }
    const editing_root = rootEditableElementOf(position);
    if ((editing_root != null and isDocumentElement(editing_root.?)) or isDocumentNode(position.anchor.?))
        return if (!next.isNull()) next else prev;
    const prev_same = !prev.isNull() and rootEditableElementOf(prev) == editing_root;
    const next_same = !next.isNull() and rootEditableElementOf(next) == editing_root;
    if (prev_same and !next_same) return prev;
    if (next_same and !prev_same) return next;
    if (!next_same and !prev_same) {
        if (editing_root != null and isVisuallyEquivalentCandidate(ctx, position)) return position;
        return .none;
    }
    const next_in_block = inSameBlock(ctx, node, next.anchor.?);
    const prev_in_block = inSameBlock(ctx, node, prev.anchor.?);
    if (prev_in_block and !next_in_block) return prev;
    return next;
}

/// Next/PreviousVisuallyDistinctCandidate (editing_utilities.cc).
fn visuallyDistinctCandidate(ctx: *Context, position: Position, rule: Rule, forward: bool) Position {
    if (position.isNull()) return .none;
    var p = Iterator.init(ctx, position);
    const skip_non_editable = rule == .can_skip_over and isEditablePosition(position);
    const boundary_rule: Rule = if (skip_non_editable) .can_cross else rule;
    const downstream_start = mostForwardCaretPosition(ctx, position, boundary_rule);
    const upstream_start = mostBackwardCaretPosition(ctx, position, boundary_rule);
    const start_root = if (skip_non_editable) rootEditableElementOf(position) else null;
    if (forward) p.increment() else p.decrement();
    while (if (forward) !p.atEnd() else !p.atStart()) : (if (forward) p.increment() else p.decrement()) {
        const candidate = p.computePosition();
        // Skip candidates inside non-editable content of the start's
        // editable root.
        if (skip_non_editable and !isEditablePosition(candidate)) {
            if (start_root) |root| {
                if (candidate.anchor) |n| if (isDescendantOf(n, root)) continue;
            }
        }
        if (isVisuallyEquivalentCandidate(ctx, candidate) and
            !mostForwardCaretPosition(ctx, candidate, boundary_rule).eql(downstream_start) and
            !mostBackwardCaretPosition(ctx, candidate, boundary_rule).eql(upstream_start))
            return candidate;
    }
    return .none;
}

/// FirstEditablePositionAfterPositionInRoot.
fn firstEditablePositionAfterPositionInRoot(ctx: *Context, position: Position, highest_root: *Instance) Position {
    if (compare(position, Position.at(highest_root, 0)) == .before and isEditable(highest_root))
        return Position.at(highest_root, 0);
    var editable = position;
    var non_editable_node: ?*Instance = null;
    while (editable.anchor) |anchor| {
        if (isEditablePosition(editable) or !isDescendantOf(anchor, highest_root)) break;
        non_editable_node = anchor;
        editable = if (isAtomicNode(anchor))
            (if (parentOf(anchor)) |p| Position.at(p, indexOf(anchor) + 1) else Position.none)
        else
            visuallyDistinctCandidate(ctx, editable, .cannot_cross, true);
    }
    const anchor = editable.anchor orelse return .none;
    if (anchor != highest_root and !isDescendantOf(anchor, highest_root)) return .none;
    if (non_editable_node) |n| {
        if (lastChildOf(anchor) == n) {
            const limit = lastPositionInNode(highest_root);
            const next = nextCandidate(ctx, editable);
            editable = if (!next.isNull() and compare(next, limit) == .before) next else limit;
        }
    }
    return editable;
}

/// LastEditablePositionBeforePositionInRoot.
fn lastEditablePositionBeforePositionInRoot(ctx: *Context, position: Position, highest_root: *Instance) Position {
    const last = lastPositionInNode(highest_root);
    if (compare(position, last) == .after) return last;
    var editable = position;
    while (editable.anchor) |anchor| {
        if (isEditablePosition(editable) or !isDescendantOf(anchor, highest_root)) break;
        editable = if (isAtomicNode(anchor))
            (if (parentOf(anchor)) |p| Position.at(p, indexOf(anchor)) else Position.none)
        else
            visuallyDistinctCandidate(ctx, editable, .cannot_cross, false);
    }
    const anchor = editable.anchor orelse return .none;
    if (anchor != highest_root and !isDescendantOf(anchor, highest_root)) return .none;
    return editable;
}

/// SkipToEndOfEditingBoundary (position_units.cc).
fn skipToEndOfEditingBoundary(ctx: *Context, pos: Position, anchor: Position) Position {
    if (pos.isNull()) return pos;
    const highest_root = highestEditableRoot(anchor);
    const highest_root_of_pos = highestEditableRoot(pos);
    if (highest_root_of_pos == highest_root) return pos;
    if (highest_root == null) return parentAnchoredEquivalent(Position.after(highest_root_of_pos.?));
    return firstEditablePositionAfterPositionInRoot(ctx, pos, highest_root.?);
}

/// SkipToStartOfEditingBoundary (position_units.cc).
fn skipToStartOfEditingBoundary(ctx: *Context, pos: Position, anchor: Position) Position {
    if (pos.isNull()) return pos;
    const highest_root = highestEditableRoot(anchor);
    const highest_root_of_pos = highestEditableRoot(pos);
    if (highest_root_of_pos == highest_root) return pos;
    if (highest_root == null)
        return visuallyDistinctCandidate(ctx, parentAnchoredEquivalent(Position.before(highest_root_of_pos.?)), .cannot_cross, false);
    return lastEditablePositionBeforePositionInRoot(ctx, pos, highest_root.?);
}

/// AdjustBackwardPositionToAvoidCrossingEditingBoundaries.
fn adjustBackwardToAvoidCrossingEditingBoundaries(ctx: *Context, pos: Position, anchor: Position) Position {
    if (pos.isNull()) return pos;
    const highest_root = highestEditableRoot(anchor);
    if (highest_root) |root| {
        if (!isInclusiveDescendantOf(pos.anchor.?, root)) {
            if (computeContainerNode(anchor)) |first| {
                if (isTextNode(first)) {
                    const first_position = Position.at(first, 0);
                    if (!anchor.eql(first_position)) return first_position;
                }
            }
            return .none;
        }
    }
    if (highestEditableRoot(pos) == highest_root) return pos;
    const root = highest_root orelse return .none;
    return lastEditablePositionBeforePositionInRoot(ctx, pos, root);
}

/// AdjustForwardPositionToAvoidCrossingEditingBoundaries.
fn adjustForwardToAvoidCrossingEditingBoundaries(ctx: *Context, pos: Position, anchor: Position) Position {
    if (pos.isNull()) return pos;
    const highest_root = highestEditableRoot(anchor);
    if (highest_root) |root| {
        if (!isDescendantOf(pos.anchor.?, root)) {
            if (computeContainerNode(anchor)) |last| {
                if (isTextNode(last)) {
                    const last_position = lastPositionInNode(last);
                    if (!anchor.eql(last_position)) return last_position;
                }
            }
            return .none;
        }
    }
    if (highestEditableRoot(pos) == highest_root) return pos;
    if (highest_root == null) {
        var last_non_editable = computeContainerNode(anchor) orelse return .none;
        var ancestor = parentOf(last_non_editable);
        while (ancestor) |a| : (ancestor = parentOf(a)) {
            if (isEditable(a)) return lastPositionInNode(last_non_editable);
            last_non_editable = a;
        }
        return .none;
    }
    return firstEditablePositionAfterPositionInRoot(ctx, pos, highest_root.?);
}

/// NextPositionOf(VisiblePosition, rule) (visible_units.cc): the next
/// visually distinct candidate, kept in (or skipped past) the editable
/// region by `rule`.
fn nextPositionOf(ctx: *Context, position: Position, rule: Rule) Position {
    const next = canonicalPosition(ctx, visuallyDistinctCandidate(ctx, position, rule, true));
    return canonicalPosition(ctx, switch (rule) {
        .can_cross => next,
        .cannot_cross => adjustForwardToAvoidCrossingEditingBoundaries(ctx, next, position),
        .can_skip_over => skipToEndOfEditingBoundary(ctx, next, position),
    });
}

/// PreviousPositionOf(VisiblePosition, rule).
fn previousPositionOf(ctx: *Context, position: Position, rule: Rule) Position {
    const prev_position = visuallyDistinctCandidate(ctx, position, rule, false);
    if (atStartOfTree(prev_position)) return .none;
    const prev = canonicalPosition(ctx, prev_position);
    if (prev.eql(position)) return .none;
    return canonicalPosition(ctx, switch (rule) {
        .can_cross => prev,
        .cannot_cross => adjustBackwardToAvoidCrossingEditingBoundaries(ctx, prev, position),
        .can_skip_over => skipToStartOfEditingBoundary(ctx, prev, position),
    });
}

/// The root editable element of the caret at `point` when the caret is
/// the only place a caret can be in it - Blink's TypingCommand::
/// DeleteKeyPressed: PreviousPositionOf and NextPositionOf(visible start,
/// kCannotCrossEditingBoundary) both null, "no visible positions in the
/// editing root" but this one - else null.
pub fn soleCaretRoot(allocator: std.mem.Allocator, point: Point) ?*Instance {
    var ctx = Context.init(allocator);
    defer ctx.deinit();
    const position = canonicalPosition(&ctx, Position.at(point.node, point.offset));
    if (position.isNull()) return null;
    if (!previousPositionOf(&ctx, position, .cannot_cross).isNull()) return null;
    if (!nextPositionOf(&ctx, position, .cannot_cross).isNull()) return null;
    return rootEditableElementOf(position);
}

/// Whether `element` is laid out as a block container (Blink's
/// LayoutBlockFlow), from its computed display.
pub fn isBlockFlow(allocator: std.mem.Allocator, element: *Instance) bool {
    var ctx = Context.init(allocator);
    defer ctx.deinit();
    switch (ctx.boxOf(element)) {
        .block, .atomic_inline => {},
        else => return false,
    }
    if (isHtmlIn(element, &replaced_names)) return false;
    const style = computedStyleOf(element) orelse return false;
    const display = style.display();
    // A table cell or caption is a block flow; a flex or grid container
    // is not (LayoutFlexibleBox, LayoutGrid).
    if (display.box == .internal) return true;
    return display.inner == .flow or display.inner == .flow_root;
}

// ============================================================================
// Words (position_units_word.cc over Blink's TextOffsetMapping)
// ============================================================================

/// Where `p` falls in its inline formatting context: the segment and the
/// number of its units before `p`.
const TextOffset = struct { segment: *const Segment, root: *Instance, index: usize, offset: u32 };

fn pointOf(p: Position) ?Point {
    const container = computeContainerNode(p) orelse return null;
    return .{ .node = container, .offset = computeOffsetInContainerNode(p) };
}

fn unitStart(unit: Unit) ?Point {
    if (unit.kind == .text) return .{ .node = unit.node, .offset = unit.offset };
    const parent = parentOf(unit.node) orelse return null;
    return .{ .node = parent, .offset = indexOf(unit.node) };
}

fn unitEnd(unit: Unit) ?Point {
    if (unit.kind == .text) return .{ .node = unit.node, .offset = unit.offset + 1 };
    const parent = parentOf(unit.node) orelse return null;
    return .{ .node = parent, .offset = indexOf(unit.node) + 1 };
}

fn pointLessOrEqual(a: Point, b: Point) bool {
    return (editing.comparePoints(a, b) catch .equal) != .after;
}

/// TextOffsetMapping::ComputeTextOffset: the segment of `p`'s inline
/// formatting context that holds it, and how many of its units end at or
/// before it.
fn textOffsetOf(ctx: *Context, p: Position) ?TextOffset {
    const point = pointOf(p) orelse return null;
    const container = point.node;
    const root = if (isElement(container) and switch (ctx.boxOf(container)) {
        .block, .atomic_inline, .other => true,
        else => false,
    }) container else (ctx.ifcRootOf(container) orelse return null);
    const inline_root = ctx.inlineRoot(root);
    for (inline_root.segments, 0..) |*segment, index| {
        const last = unitEnd(segment.units[segment.units.len - 1]) orelse continue;
        const is_last = index + 1 == inline_root.segments.len;
        if (!is_last and !pointLessOrEqual(point, last)) continue;
        var offset: u32 = 0;
        for (segment.units) |unit| {
            const end = unitEnd(unit) orelse break;
            if (!pointLessOrEqual(end, point)) break;
            offset += 1;
        }
        return .{ .segment = segment, .root = root, .index = index, .offset = offset };
    }
    return null;
}

/// TextOffsetMapping::GetPositionBefore: just before unit `offset`.
fn positionBeforeUnit(segment: *const Segment, offset: u32) Position {
    if (offset >= segment.units.len) return positionAfterUnit(segment, @intCast(segment.units.len - 1));
    const unit = segment.units[offset];
    return switch (unit.kind) {
        .text => Position.at(unit.node, unit.offset),
        else => Position.before(unit.node),
    };
}

/// TextOffsetMapping::GetPositionAfter: just after unit `offset`.
fn positionAfterUnit(segment: *const Segment, offset: u32) Position {
    const unit = segment.units[offset];
    return switch (unit.kind) {
        .text => Position.at(unit.node, unit.offset + 1),
        else => Position.after(unit.node),
    };
}

/// The segment before (or after) segment `index` of `root` in tree order:
/// the previous one in the same root, or the nearest one of another
/// inline formatting context (TextSegments' walk over InlineContents).
fn adjacentSegment(ctx: *Context, from: TextOffset, forward: bool) ?TextOffset {
    const inline_root = ctx.inlineRoot(from.root);
    if (forward and from.index + 1 < inline_root.segments.len)
        return .{ .segment = &inline_root.segments[from.index + 1], .root = from.root, .index = from.index + 1, .offset = 0 };
    if (!forward and from.index > 0) {
        const segment = &inline_root.segments[from.index - 1];
        return .{ .segment = segment, .root = from.root, .index = from.index - 1, .offset = @intCast(segment.units.len) };
    }
    // Leave the root: walk text in tree order to the next rendered unit
    // outside it.
    const edge = if (forward) from.segment.units[from.segment.units.len - 1] else from.segment.units[0];
    // Forward from an atomic inline skips its own content (a context of
    // its own, inside the unit already passed).
    var node: ?*Instance = if (!forward)
        editing.previousInTreeOrder(edge.node) catch null
    else if (edge.kind == .text)
        editing.nextInTreeOrder(edge.node) catch null
    else
        editing.nextSkippingChildren(edge.node) catch null;
    while (node) |candidate| : (node = if (forward) editing.nextInTreeOrder(candidate) catch null else editing.previousInTreeOrder(candidate) catch null) {
        if (!isTextNode(candidate)) continue;
        if (!ctx.textInfo(candidate).hasNonCollapsedText()) continue;
        const found = textOffsetOf(ctx, Position.at(candidate, 0)) orelse continue;
        if (found.root == from.root and found.index == from.index) continue;
        return .{
            .segment = found.segment,
            .root = found.root,
            .index = found.index,
            .offset = if (forward) 0 else @intCast(found.segment.units.len),
        };
    }
    return null;
}

/// Blink's IsWordBreak: a printable non-space, a surrogate, a line break
/// or a low line.
fn isWordBreak(unit: u16) bool {
    return switch (unit) {
        ' ', '\t', 0xA0 => false,
        '\n', '\r', '_' => true,
        else => unit > 0x20 and unit != 0x7f,
    };
}

/// Crane's word movement policy over the text content of an inline
/// formatting context (word_navigation.move: Q15/Q16's next-word-start
/// convention) - the per-string Finder of Blink's Next/PreviousWordPosition
/// - with TextSegments' walk to the neighbouring context when the search
/// starts at a context's edge.
fn wordPosition(ctx: *Context, position: Position, forward: bool) Position {
    const start = textOffsetOf(ctx, position) orelse return .none;
    var current = start;
    var first = true;
    var guard: usize = 0;
    while (guard < 4096) : (guard += 1) {
        const text = current.segment.text;
        const len: u32 = @intCast(text.len);
        if (!first) {
            // A later context: its edge is the answer when a word touches it.
            if (forward and len > 0 and isWordBreak(text[0])) return positionBeforeUnit(current.segment, 0);
            if (!forward and len > 0 and isWordBreak(text[len - 1])) return positionAfterUnit(current.segment, len - 1);
        }
        const at_edge = if (forward) current.offset >= len else current.offset == 0;
        if (!at_edge) {
            const bytes = unitsToWtf8(ctx.arena(), text) orelse return .none;
            const moved = word_navigation.move(bytes, current.offset, forward);
            if (moved != current.offset or !first) {
                if (moved >= len) return positionAfterUnit(current.segment, len - 1);
                return positionBeforeUnit(current.segment, moved);
            }
        }
        first = false;
        current = adjacentSegment(ctx, current, forward) orelse return .none;
    }
    return .none;
}

fn unitsToWtf8(allocator: std.mem.Allocator, units: []const u16) ?[]const u8 {
    var list: std.ArrayList(u8) = .empty;
    appendWtf8(allocator, &list, units) catch return null;
    return list.items;
}

// ============================================================================
// Selection.modify (selection_modifier.cc)
// ============================================================================

pub const Granularity = enum { character, word };

/// What Selection.modify knows of the selection it moves.
pub const Selection = struct {
    focus: Point,
    /// The range's start and end when it is not collapsed.
    range: ?struct { start: Point, end: Point } = null,
};

/// SelectionModifier::ComputeModifyPosition for the character and word
/// granularities: the DOM boundary point the focus moves to (the caret,
/// for "move"), or null where Blink's modify returns false and the
/// selection stays. "forward" and "right" move forward, "backward" and
/// "left" backward (an LTR block; see the file comment for bidi).
pub fn modifyPosition(allocator: std.mem.Allocator, selection: Selection, extend: bool, forward: bool, granularity: Granularity) ?Point {
    var ctx = Context.init(allocator);
    defer ctx.deinit();
    const result = computeModifyPosition(&ctx, selection, extend, forward, granularity);
    if (result.isNull()) return null;
    const dom_position = parentAnchoredEquivalent(result);
    const node = dom_position.anchor orelse return null;
    return .{ .node = node, .offset = dom_position.offset };
}

fn computeModifyPosition(ctx: *Context, selection: Selection, extend: bool, forward: bool, granularity: Granularity) Position {
    // ComputeVisibleFocus: the canonical form of the focus.
    const focus = canonicalPosition(ctx, Position.at(selection.focus.node, selection.focus.offset));
    switch (granularity) {
        .character => {
            // ModifyMovingForward / Backward: a range collapses to its end
            // or start.
            if (!extend) if (selection.range) |range| {
                const edge = if (forward) range.end else range.start;
                return canonicalPosition(ctx, Position.at(edge.node, edge.offset));
            };
            if (focus.isNull()) return .none;
            return if (forward) nextPositionOf(ctx, focus, .can_skip_over) else previousPositionOf(ctx, focus, .can_skip_over);
        },
        .word => {
            if (focus.isNull()) return .none;
            const target = wordPosition(ctx, focus, forward);
            const adjusted = if (forward)
                adjustForwardToAvoidCrossingEditingBoundaries(ctx, target, focus)
            else
                adjustBackwardToAvoidCrossingEditingBoundaries(ctx, target, focus);
            return canonicalPosition(ctx, adjusted);
        },
    }
}
