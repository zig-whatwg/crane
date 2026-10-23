//! The Editing spec's common definitions and assorted common algorithms
//! (specs/w3c/execCommand.md "Common definitions", "Assorted common
//! algorithms", "Allowed children", "Block formatting command definitions").
//!
//! Every definition here reads the DOM through the generated interfaces and
//! the dom hook modules, never an impl (AGENTS.md "The impls boundary").
//! Offsets are UTF-16 code units, as the spec's boundary points are.
//!
//! The spec defines "collapsed line break" and "extraneous line break" by
//! layout (a br's effect on its block's height). Crane has no layout, so
//! those two are the DOM rules Gecko's editor uses for the same questions
//! (editor/libeditor/HTMLEditUtils.cpp): a br is collapsed when it is
//! followed by a block boundary (IsBRElementFollowedByBlockBoundary), and
//! extraneous - Gecko's "unnecessary" br - when it is followed by a block
//! boundary but does not itself follow a line boundary
//! (IsUnnecessaryBRElement). See `isCollapsedLineBreak`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const webidl = @import("webidl");
const ComputedStyle = @import("css").computed_style.ComputedStyle;

pub const Instance = runtime.Instance;
const DOMString = runtime.DOMString;

pub const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";
const mathml_namespace = "http://www.w3.org/1998/Math/MathML";

/// A boundary point: (node, offset).
pub const Point = struct {
    node: *Instance,
    offset: u32,

    pub fn eql(a: Point, b: Point) bool {
        return a.node == b.node and a.offset == b.offset;
    }
};

/// The state one command action carries: the document and its selection,
/// and whether any step changed the DOM (the input event fires only then,
/// execCommand() step 7).
pub const Edit = struct {
    document: *Instance,
    selection: *Instance,
    allocator: std.mem.Allocator,
    modified: bool = false,

    /// The active range: the selection's range, or null.
    pub fn activeRange(self: *Edit) !?*Instance {
        if ((try interfaces.Selection.get_rangeCount(self.selection)) == 0) return null;
        return try interfaces.Selection.call_getRangeAt(self.selection, 0);
    }

    pub fn rangeStart(self: *Edit) !?Point {
        const range = (try self.activeRange()) orelse return null;
        return .{ .node = try interfaces.AbstractRange.get_startContainer(range), .offset = try interfaces.AbstractRange.get_startOffset(range) };
    }

    pub fn rangeEnd(self: *Edit) !?Point {
        const range = (try self.activeRange()) orelse return null;
        return .{ .node = try interfaces.AbstractRange.get_endContainer(range), .offset = try interfaces.AbstractRange.get_endOffset(range) };
    }

    pub fn rangeCollapsed(self: *Edit) !bool {
        const range = (try self.activeRange()) orelse return true;
        return try interfaces.AbstractRange.get_collapsed(range);
    }

    /// Selection.collapse(node, offset).
    pub fn collapse(self: *Edit, node: *Instance, offset: u32) !void {
        try interfaces.Selection.call_collapse(self.selection, node, webidl.Opt(u32).passed(offset));
    }

    /// Selection.extend(node, offset).
    pub fn extend(self: *Edit, node: *Instance, offset: u32) !void {
        try interfaces.Selection.call_extend(self.selection, node, webidl.Opt(u32).passed(offset));
    }

    pub fn collapseToStart(self: *Edit) !void {
        try interfaces.Selection.call_collapseToStart(self.selection);
    }

    pub fn collapseToEnd(self: *Edit) !void {
        try interfaces.Selection.call_collapseToEnd(self.selection);
    }

    // ---- DOM mutation primitives: every change goes through one of these,
    // so `modified` is exact.

    /// Remove `node` from its parent (no-op without one).
    pub fn removeNode(self: *Edit, node: *Instance) !void {
        const p = (try parent(node)) orelse return;
        _ = try interfaces.Node.call_removeChild(p, node);
        self.modified = true;
    }

    /// Insert `node` into `new_parent` before `reference` (null: append).
    pub fn insertBefore(self: *Edit, new_parent: *Instance, node: *Instance, reference: ?*Instance) !void {
        _ = try interfaces.Node.call_insertBefore(new_parent, node, reference);
        self.modified = true;
    }

    pub fn appendChild(self: *Edit, new_parent: *Instance, node: *Instance) !void {
        _ = try interfaces.Node.call_appendChild(new_parent, node);
        self.modified = true;
    }

    /// CharacterData.deleteData(offset, count).
    pub fn deleteData(self: *Edit, node: *Instance, offset: u32, count: u32) !void {
        if (count == 0) return;
        try interfaces.CharacterData.call_deleteData(node, offset, count);
        self.modified = true;
    }

    /// CharacterData.insertData(offset, data).
    pub fn insertData(self: *Edit, node: *Instance, offset: u32, data: []const u8) !void {
        try interfaces.CharacterData.call_insertData(node, offset, DOMString.initInterned(data));
        self.modified = true;
    }

    /// createElement(name) on the document.
    pub fn createElement(self: *Edit, name: []const u8) !*Instance {
        return try interfaces.Document.call_createElement(self.document, DOMString.initInterned(name), webidl.Opt(runtime.JSValue).notPassed());
    }

    /// Move `node` to (new_parent, new_index), preserving ranges ("Assorted
    /// common algorithms"): the live ranges' boundary points follow the
    /// spec's four rules instead of the insert and remove algorithms'.
    pub fn movePreservingRanges(self: *Edit, node: *Instance, new_parent: *Instance, new_index_in: u32) !void {
        var new_index = new_index_in;
        const count = try childCount(new_parent);
        if (new_index > count) new_index = count;
        // Step 1: node, old parent and old index, new parent and new index.
        const old_parent = try parent(node);
        const old_index: u32 = if (old_parent != null) try indexOf(node) else 0;
        // Snapshot every live range of the document with the adjusted points
        // (steps 2-5), then move, then write the points back.
        var adjusted: std.ArrayList(AdjustedRange) = .empty;
        defer adjusted.deinit(self.allocator);
        if (dom.document_internals.liveRanges(self.document)) |ranges| {
            if (dom.range_boundaries.liveRange()) |live| {
                var walk: dom.document_internals.LiveObjects.Walk = undefined;
                ranges.beginWalk(&walk);
                defer ranges.endWalk(&walk);
                while (walk.nextEntry()) |range| {
                    const points = live.points(range) orelse continue;
                    const start_node = points.start_container orelse continue;
                    const end_node = points.end_container orelse continue;
                    var entry: AdjustedRange = .{
                        .range = range,
                        .start = .{ .node = start_node, .offset = points.start_offset },
                        .end = .{ .node = end_node, .offset = points.end_offset },
                    };
                    adjustPoint(&entry.start, node, old_parent, old_index, new_parent, new_index);
                    adjustPoint(&entry.end, node, old_parent, old_index, new_parent, new_index);
                    try adjusted.append(self.allocator, entry);
                }
            }
        }
        // The same-parent move: the reference child is read before the
        // removal, as the reference implementation does.
        const reference = try childAt(new_parent, new_index);
        try self.insertBefore(new_parent, node, if (reference == node) try nextSibling(node) else reference);
        if (dom.range_boundaries.liveRange()) |live| {
            for (adjusted.items) |entry| {
                live.set_start(entry.range, entry.start.node, entry.start.offset);
                live.set_end(entry.range, entry.end.node, entry.end.offset);
            }
        }
    }

    const AdjustedRange = struct { range: *Instance, start: Point, end: Point };

    fn adjustPoint(point: *Point, moved: *Instance, old_parent: ?*Instance, old_index: u32, new_parent: *Instance, new_index: u32) void {
        // Step 2: a point in the moved node or its descendants moves with it.
        if (point.node == moved) return;
        if (isDescendantOf(point.node, moved)) return;
        // Step 3: a point in new parent past new index shifts right by one.
        if (point.node == new_parent and point.offset > new_index) point.offset += 1;
        // Step 4: a point at or just after the node in old parent follows it.
        if (old_parent != null and point.node == old_parent.? and (point.offset == old_index or point.offset == old_index + 1)) {
            point.node = new_parent;
            point.offset = point.offset + new_index - old_index;
            return;
        }
        // Step 5: a point in old parent past the node shifts left by one.
        if (old_parent != null and point.node == old_parent.? and point.offset > old_index + 1) point.offset -= 1;
    }

    /// "set the tag name" of `element` to `new_name`; the element to use
    /// afterwards.
    pub fn setTagName(self: *Edit, element: *Instance, new_name: []const u8) !*Instance {
        // Step 1: already that HTML element.
        if (try isHtmlElementNamed(element, new_name)) return element;
        // Step 2: no parent.
        const p = (try parent(element)) orelse return element;
        // Steps 3-4: the replacement, inserted before element.
        const replacement = try self.createElement(new_name);
        try self.insertBefore(p, replacement, element);
        // Step 5: copy the attributes in order.
        const attributes = try interfaces.Element.get_attributes(element);
        const attribute_count = try interfaces.NamedNodeMap.get_length(attributes);
        var i: u32 = 0;
        while (i < attribute_count) : (i += 1) {
            const attr = (try interfaces.NamedNodeMap.call_item(attributes, i)) orelse continue;
            var name = try interfaces.Attr.get_name(attr);
            defer name.deinit(element.ctx.allocator);
            var value = try interfaces.Attr.get_value(attr);
            defer value.deinit(element.ctx.allocator);
            try setAttribute(replacement, name.asSlice(), value.asSlice());
            self.modified = true;
        }
        // Step 6: move the children, preserving ranges.
        while (try firstChild(element)) |child| {
            try self.movePreservingRanges(child, replacement, try childCount(replacement));
        }
        // Step 7: remove element.
        try self.removeNode(element);
        return replacement;
    }

    /// "remove extraneous line breaks before" `node`.
    pub fn removeExtraneousLineBreaksBefore(self: *Edit, node: *Instance) !void {
        // Steps 1-2.
        var ref = (try previousSibling(node)) orelse return;
        // Step 3.
        while (try lastChild(ref)) |last| ref = last;
        // Step 4.
        const node_parent = try parent(node);
        while ((try isInvisible(ref)) and !(try isExtraneousLineBreak(ref)) and ref != node_parent) {
            ref = (try previousInTreeOrder(ref)) orelse return;
        }
        // Step 5.
        if ((try isEditable(ref)) and try isExtraneousLineBreak(ref)) try self.removeNode(ref);
    }

    /// "remove extraneous line breaks at the end of" `node`.
    pub fn removeExtraneousLineBreaksAtTheEndOf(self: *Edit, node: *Instance) !void {
        // Steps 1-2.
        var ref = node;
        while (try lastChild(ref)) |last| ref = last;
        // Step 3.
        while ((try isInvisible(ref)) and !(try isExtraneousLineBreak(ref)) and ref != node) {
            ref = (try previousInTreeOrder(ref)) orelse return;
        }
        // Step 4.
        if ((try isEditable(ref)) and try isExtraneousLineBreak(ref)) {
            // Step 4.1: the block ending in <span><br></span> loses the span too.
            while (try parent(ref)) |p| {
                if (!((try isEditable(p)) and try isInvisible(p))) break;
                ref = p;
            }
            // Step 4.2.
            try self.removeNode(ref);
        }
    }

    /// "remove extraneous line breaks from" `node`.
    pub fn removeExtraneousLineBreaksFrom(self: *Edit, node: *Instance) !void {
        try self.removeExtraneousLineBreaksBefore(node);
        try self.removeExtraneousLineBreaksAtTheEndOf(node);
    }
};

/// Element.setAttribute(name, value).
pub fn setAttribute(element: *Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, DOMString.initInterned(name), .{ .domstring = DOMString.initInterned(value) });
}

/// Element.removeAttribute(name).
pub fn removeAttribute(element: *Instance, name: []const u8) !void {
    try interfaces.Element.call_removeAttribute(element, DOMString.initInterned(name));
}

/// Node.cloneNode(deep).
pub fn cloneNode(node: *Instance, deep: bool) !*Instance {
    return try interfaces.Node.call_cloneNode(node, webidl.Opt(bool).passed(deep));
}

// ============================================================================
// Tree reading
// ============================================================================

pub fn nodeType(node: *Instance) !u16 {
    return try interfaces.Node.get_nodeType(node);
}

pub fn isText(node: *Instance) bool {
    const t = nodeType(node) catch return false;
    return t == interfaces.Node.get_TEXT_NODE() or t == interfaces.Node.get_CDATA_SECTION_NODE();
}

pub fn isElement(node: *Instance) bool {
    return (nodeType(node) catch return false) == interfaces.Node.get_ELEMENT_NODE();
}

pub fn isDocument(node: *Instance) bool {
    return (nodeType(node) catch return false) == interfaces.Node.get_DOCUMENT_NODE();
}

pub fn isDocumentFragment(node: *Instance) bool {
    return (nodeType(node) catch return false) == interfaces.Node.get_DOCUMENT_FRAGMENT_NODE();
}

pub fn isDocumentType(node: *Instance) bool {
    return (nodeType(node) catch return false) == interfaces.Node.get_DOCUMENT_TYPE_NODE();
}

/// Whether the node is a Text, Comment or ProcessingInstruction: its length
/// is its data's.
fn isCharacterData(node: *Instance) bool {
    const t = nodeType(node) catch return false;
    return t == interfaces.Node.get_TEXT_NODE() or t == interfaces.Node.get_CDATA_SECTION_NODE() or
        t == interfaces.Node.get_COMMENT_NODE() or t == interfaces.Node.get_PROCESSING_INSTRUCTION_NODE();
}

pub fn parent(node: *Instance) !?*Instance {
    return try interfaces.Node.get_parentNode(node);
}

pub fn firstChild(node: *Instance) !?*Instance {
    return try interfaces.Node.get_firstChild(node);
}

pub fn lastChild(node: *Instance) !?*Instance {
    return try interfaces.Node.get_lastChild(node);
}

pub fn nextSibling(node: *Instance) !?*Instance {
    return try interfaces.Node.get_nextSibling(node);
}

pub fn previousSibling(node: *Instance) !?*Instance {
    return try interfaces.Node.get_previousSibling(node);
}

pub fn hasChildren(node: *Instance) !bool {
    return (try firstChild(node)) != null;
}

pub fn childCount(node: *Instance) !u32 {
    var count: u32 = 0;
    var child = try firstChild(node);
    while (child) |c| : (child = try nextSibling(c)) count += 1;
    return count;
}

/// The child of `node` with index `index`, or null.
pub fn childAt(node: *Instance, index: u32) !?*Instance {
    var i: u32 = 0;
    var child = try firstChild(node);
    while (child) |c| : (child = try nextSibling(c)) {
        if (i == index) return c;
        i += 1;
    }
    return null;
}

/// The child of `node` with index `index - 1`, or null when index is 0.
pub fn childBefore(node: *Instance, index: u32) !?*Instance {
    if (index == 0) return null;
    return try childAt(node, index - 1);
}

/// The point just before `node` in its parent `p`: (p, index of node).
/// A helper rather than a struct literal because
/// `point = .{ .node = p, .offset = indexOf(point.node) }` writes `.node`
/// into `point` before `.offset` is computed (Zig result locations), so
/// `indexOf` would see the parent.
pub fn pointBefore(node: *Instance, p: *Instance) !Point {
    const index = try indexOf(node);
    return .{ .node = p, .offset = index };
}

/// The point just after `node` in its parent `p`: (p, 1 + index of node).
pub fn pointAfter(node: *Instance, p: *Instance) !Point {
    const index = try indexOf(node);
    return .{ .node = p, .offset = index + 1 };
}

/// The tree index of `node` among its parent's children (0 without a parent).
pub fn indexOf(node: *Instance) !u32 {
    var index: u32 = 0;
    var sibling = try previousSibling(node);
    while (sibling) |s| : (sibling = try previousSibling(s)) index += 1;
    return index;
}

/// DOM "length" of a node: its data's UTF-16 length for character data,
/// zero for a doctype, the number of children otherwise.
pub fn nodeLength(node: *Instance) !u32 {
    if (isCharacterData(node)) return try interfaces.CharacterData.get_length(node);
    if (isDocumentType(node)) return 0;
    return try childCount(node);
}

/// The data of a character data node, OWNED (deinit with its allocator).
pub fn textData(node: *Instance) !DOMString {
    return try interfaces.CharacterData.get_data(node);
}

pub fn isDescendantOf(node: *Instance, ancestor: *Instance) bool {
    var current = parent(node) catch return false;
    while (current) |c| : (current = parent(c) catch return false) {
        if (c == ancestor) return true;
    }
    return false;
}

pub fn isInclusiveDescendantOf(node: *Instance, ancestor: *Instance) bool {
    return node == ancestor or isDescendantOf(node, ancestor);
}

pub fn isAncestorOf(node: *Instance, descendant: *Instance) bool {
    return isDescendantOf(descendant, node);
}

/// The node after `node` in tree order, or null.
pub fn nextInTreeOrder(node: *Instance) !?*Instance {
    if (try firstChild(node)) |child| return child;
    var current: ?*Instance = node;
    while (current) |c| : (current = try parent(c)) {
        if (try nextSibling(c)) |sibling| return sibling;
    }
    return null;
}

/// The node after `node` in tree order, skipping `node`'s descendants.
pub fn nextSkippingChildren(node: *Instance) !?*Instance {
    var current: ?*Instance = node;
    while (current) |c| : (current = try parent(c)) {
        if (try nextSibling(c)) |sibling| return sibling;
    }
    return null;
}

/// The node before `node` in tree order, or null.
pub fn previousInTreeOrder(node: *Instance) !?*Instance {
    if (try previousSibling(node)) |sibling| {
        var last = sibling;
        while (try lastChild(last)) |child| last = child;
        return last;
    }
    return try parent(node);
}

/// (a) is before (b) in the boundary point order of DOM 5.2.
pub fn pointIsBefore(a: Point, b: Point) !bool {
    return (try comparePoints(a, b)) == .before;
}

pub fn pointIsAfter(a: Point, b: Point) !bool {
    return (try comparePoints(a, b)) == .after;
}

pub const PointOrder = enum { before, equal, after };

/// DOM 5.2 "position of a boundary point relative to another".
pub fn comparePoints(a: Point, b: Point) !PointOrder {
    // Step 2: same node.
    if (a.node == b.node) {
        if (a.offset == b.offset) return .equal;
        return if (a.offset < b.offset) .before else .after;
    }
    // Step 3: node A follows node B: the reverse of B relative to A.
    if (try follows(a.node, b.node)) {
        return switch (try comparePoints(b, a)) {
            .before => .after,
            .after => .before,
            .equal => .equal,
        };
    }
    // Step 4: node A is an ancestor of node B.
    if (isAncestorOf(a.node, b.node)) {
        var child = b.node;
        while ((try parent(child)) != a.node) child = (try parent(child)) orelse break;
        if ((try indexOf(child)) < a.offset) return .after;
    }
    // Step 5.
    return .before;
}

/// Whether `a` follows `b` in tree order (both in one tree).
fn follows(a: *Instance, b: *Instance) !bool {
    const position = try interfaces.Node.call_compareDocumentPosition(b, a);
    return position & interfaces.Node.get_DOCUMENT_POSITION_FOLLOWING() != 0;
}

// ============================================================================
// Names and namespaces
// ============================================================================

/// Whether `node` is an element in the HTML namespace.
pub fn isHtmlElement(node: *Instance) !bool {
    if (!isElement(node)) return false;
    var namespace = try interfaces.Element.get_namespaceURI(node);
    defer if (namespace) |*n| n.deinit(node.ctx.allocator);
    return namespace != null and std.mem.eql(u8, namespace.?.asSlice(), html_namespace);
}

fn isElementInNamespaceNamed(node: *Instance, namespace_uri: []const u8, name: []const u8) !bool {
    if (!isElement(node)) return false;
    var namespace = try interfaces.Element.get_namespaceURI(node);
    defer if (namespace) |*n| n.deinit(node.ctx.allocator);
    if (namespace == null or !std.mem.eql(u8, namespace.?.asSlice(), namespace_uri)) return false;
    return try localNameIs(node, name);
}

/// Whether `node`'s local name is exactly `name`.
pub fn localNameIs(node: *Instance, name: []const u8) !bool {
    if (!isElement(node)) return false;
    var local = try interfaces.Element.get_localName(node);
    defer local.deinit(node.ctx.allocator);
    return std.mem.eql(u8, local.asSlice(), name);
}

/// Whether `node`'s local name is one of `names`.
pub fn localNameIn(node: *Instance, names: []const []const u8) !bool {
    if (!isElement(node)) return false;
    var local = try interfaces.Element.get_localName(node);
    defer local.deinit(node.ctx.allocator);
    return nameIn(local.asSlice(), names);
}

pub fn nameIn(name: []const u8, names: []const []const u8) bool {
    for (names) |candidate| if (std.mem.eql(u8, name, candidate)) return true;
    return false;
}

/// An HTML element with local name `name`.
pub fn isHtmlElementNamed(node: *Instance, name: []const u8) !bool {
    return (try isHtmlElement(node)) and try localNameIs(node, name);
}

/// An HTML element whose local name is one of `names`.
pub fn isHtmlElementIn(node: *Instance, names: []const []const u8) !bool {
    return (try isHtmlElement(node)) and try localNameIn(node, names);
}

/// `node`'s local name copied into `buffer`, or null when it is not an
/// element or does not fit.
pub fn localNameInto(node: *Instance, buffer: []u8) !?[]const u8 {
    if (!isElement(node)) return null;
    var local = try interfaces.Element.get_localName(node);
    defer local.deinit(node.ctx.allocator);
    const name = local.asSlice();
    if (name.len > buffer.len) return null;
    @memcpy(buffer[0..name.len], name);
    return buffer[0..name.len];
}

pub fn hasAttribute(element: *Instance, name: []const u8) !bool {
    if (!isElement(element)) return false;
    return try interfaces.Element.call_hasAttribute(element, DOMString.initInterned(name));
}

/// The names that close a <p>: "prohibited paragraph child name".
pub const prohibited_paragraph_child_names = [_][]const u8{
    "address", "article", "aside", "blockquote", "caption",   "center",     "col",     "colgroup", "dd",    "details",
    "dir",     "div",     "dl",    "dt",         "fieldset",  "figcaption", "figure",  "footer",   "form",  "h1",
    "h2",      "h3",      "h4",    "h5",         "h6",        "header",     "hgroup",  "hr",       "li",    "listing",
    "menu",    "nav",     "ol",    "p",          "plaintext", "pre",        "section", "summary",  "table", "tbody",
    "td",      "tfoot",   "th",    "thead",      "tr",        "ul",         "xmp",
};

pub fn isProhibitedParagraphChild(node: *Instance) !bool {
    return try isHtmlElementIn(node, &prohibited_paragraph_child_names);
}

/// "name of an element with inline contents".
pub const inline_contents_names = [_][]const u8{
    "a",   "abbr", "b",     "bdi",  "bdo",     "cite", "code", "dfn", "em",  "h1",      "h2",      "h3",
    "h4",  "h5",   "h6",    "i",    "kbd",     "mark", "p",    "pre", "q",   "rp",      "rt",      "ruby",
    "s",   "samp", "small", "span", "strong",  "sub",  "sup",  "u",   "var", "acronym", "listing", "strike",
    "xmp", "big",  "blink", "font", "marquee", "nobr", "tt",
};

pub fn isElementWithInlineContents(node: *Instance) !bool {
    return try isHtmlElementIn(node, &inline_contents_names);
}

/// "indentation element": a blockquote, or a div whose style attribute
/// sets margin or a subproperty of it.
pub fn isIndentationElement(node: *Instance) !bool {
    if (try isHtmlElementNamed(node, "blockquote")) return true;
    if (!try isHtmlElementNamed(node, "div")) return false;
    var style = (try interfaces.Element.call_getAttribute(node, DOMString.initInterned("style"))) orelse return false;
    defer style.deinit(node.ctx.allocator);
    // A declaration whose property name starts with "margin".
    var declarations = std.mem.splitScalar(u8, style.asSlice(), ';');
    while (declarations.next()) |declaration| {
        const colon = std.mem.indexOfScalar(u8, declaration, ':') orelse continue;
        const property = std.mem.trim(u8, declaration[0..colon], " \t\n\r");
        if (std.ascii.startsWithIgnoreCase(property, "margin")) return true;
    }
    return false;
}

pub const non_list_single_line_container_names = [_][]const u8{ "address", "div", "h1", "h2", "h3", "h4", "h5", "h6", "listing", "p", "pre", "xmp" };

pub fn isNonListSingleLineContainer(node: *Instance) !bool {
    return try isHtmlElementIn(node, &non_list_single_line_container_names);
}

pub fn isSingleLineContainer(node: *Instance) !bool {
    return (try isNonListSingleLineContainer(node)) or try isHtmlElementIn(node, &.{ "li", "dt", "dd" });
}

// ============================================================================
// Editing hosts and editability
// ============================================================================

/// HTML "editing host": an HTML element whose contenteditable is in the
/// true or plaintext-only state, or an HTML element child of a document
/// whose design mode is on.
pub fn isEditingHost(node: *Instance) !bool {
    if (!try isHtmlElement(node)) return false;
    var state = try interfaces.HTMLElement.get_contentEditable(node);
    defer state.deinit(node.ctx.allocator);
    const value = state.asSlice();
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "plaintext-only")) return true;
    const p = (try parent(node)) orelse return false;
    if (!isDocument(p)) return false;
    var mode = try interfaces.Document.get_designMode(p);
    defer mode.deinit(p.ctx.allocator);
    return std.mem.eql(u8, mode.asSlice(), "on");
}

/// Whether an element's contenteditable attribute is in the false state.
fn contentEditableIsFalse(node: *Instance) !bool {
    if (!try isHtmlElement(node)) return false;
    var state = try interfaces.HTMLElement.get_contentEditable(node);
    defer state.deinit(node.ctx.allocator);
    return std.mem.eql(u8, state.asSlice(), "false");
}

/// "editable": a node that is not an editing host, has no contenteditable
/// in the false state, whose parent is an editing host or editable, and
/// which is an HTML element, an svg or math element, or a non-element whose
/// parent is an HTML element.
pub fn isEditable(node: *Instance) !bool {
    if (try isEditingHost(node)) return false;
    if (try contentEditableIsFalse(node)) return false;
    const p = (try parent(node)) orelse return false;
    if (!((try isEditingHost(p)) or try isEditable(p))) return false;
    if (try isHtmlElement(node)) return true;
    if (try isElementInNamespaceNamed(node, svg_namespace, "svg")) return true;
    if (try isElementInNamespaceNamed(node, mathml_namespace, "math")) return true;
    return !isElement(node) and try isHtmlElement(p);
}

/// "editing host of" `node`: null when node is neither editable nor an
/// editing host, node itself when it is an editing host, else its nearest
/// editing host ancestor.
pub fn editingHostOf(node: *Instance) !?*Instance {
    if (try isEditingHost(node)) return node;
    if (!try isEditable(node)) return null;
    var current = try parent(node);
    while (current) |c| : (current = try parent(c)) {
        if (try isEditingHost(c)) return c;
    }
    return null;
}

/// "in the same editing host".
pub fn inSameEditingHost(a: *Instance, b: *Instance) !bool {
    const host = (try editingHostOf(a)) orelse return false;
    return host == try editingHostOf(b);
}

/// Editable or an editing host.
pub fn isEditableOrEditingHost(node: *Instance) !bool {
    return (try isEditable(node)) or try isEditingHost(node);
}

// ============================================================================
// Computed style: block and inline nodes, white-space, display: none
// ============================================================================

/// The resolved "white-space" of an element, from the computed
/// white-space-collapse and text-wrap-mode longhands (CSS Text 4).
pub const WhiteSpace = enum {
    normal,
    nowrap,
    pre,
    pre_wrap,
    pre_line,
    break_spaces,

    /// "pre" or "pre-wrap" (and break-spaces, which preserves spaces the
    /// same way): spaces never collapse.
    pub fn preservesSpaces(self: WhiteSpace) bool {
        return self == .pre or self == .pre_wrap or self == .break_spaces;
    }

    /// Preserves segment breaks (a LF is a line end).
    pub fn preservesNewlines(self: WhiteSpace) bool {
        return self != .normal and self != .nowrap;
    }
};

/// The computed display of an element, or null without a computed style.
fn computedStyleOf(element: *Instance) ?*const ComputedStyle {
    return dom.style.computedStyle(element, null) catch null;
}

/// The resolved white-space of `element`; normal without a computed style.
pub fn whiteSpaceOf(element: *Instance) WhiteSpace {
    const style = computedStyleOf(element) orelse return .normal;
    const collapse = style.keyword(.white_space_collapse);
    const wrap = style.keyword(.text_wrap_mode);
    const nowrap = wrap == .nowrap;
    return switch (collapse) {
        .preserve => if (nowrap) .pre else .pre_wrap,
        .preserve_breaks => .pre_line,
        .break_spaces => .break_spaces,
        else => if (nowrap) .nowrap else .normal,
    };
}

/// The resolved white-space that applies to `node`'s text: its parent
/// element's for a Text node.
pub fn whiteSpaceAround(node: *Instance) !WhiteSpace {
    if (isElement(node)) return whiteSpaceOf(node);
    const p = (try parent(node)) orelse return .normal;
    if (!isElement(p)) return .normal;
    return whiteSpaceOf(p);
}

/// Whether an element's computed display is none.
pub fn displayIsNone(element: *Instance) bool {
    const style = computedStyleOf(element) orelse return false;
    return style.display().box == .none;
}

/// "block node": an Element whose resolved display is not inline,
/// inline-block, inline-table or none; or a Document or DocumentFragment.
/// An element without a computed style counts as a block, as Chrome's ""
/// resolved value does in the reference implementation.
pub fn isBlockNode(node: *Instance) bool {
    if (isDocument(node) or isDocumentFragment(node)) return true;
    if (!isElement(node)) return false;
    const style = computedStyleOf(node) orelse return true;
    const display = style.display();
    return switch (display.box) {
        .none => false,
        .contents, .internal => true,
        .normal => !(display.outer == .inline_ and (display.inner == .flow or display.inner == .flow_root or display.inner == .table)),
    };
}

pub fn isInlineNode(node: *Instance) bool {
    return !isBlockNode(node);
}

/// Whether `node` or an ancestor element has display: none.
pub fn hasDisplayNoneInclusiveAncestor(node: *Instance) !bool {
    var current: ?*Instance = node;
    while (current) |c| : (current = try parent(c)) {
        if (isElement(c) and displayIsNone(c)) return true;
    }
    return false;
}

/// "block node of" `node`: its nearest inclusive ancestor block node.
pub fn blockNodeOf(node: *Instance) !?*Instance {
    var current: ?*Instance = node;
    while (current) |c| : (current = try parent(c)) {
        if (isBlockNode(c)) return c;
    }
    return null;
}

// ============================================================================
// Visibility
// ============================================================================

fn isWhitespaceData(data: []const u8, allow_lf: bool) bool {
    if (data.len == 0) return true;
    for (data) |byte| switch (byte) {
        ' ', '\t', '\r' => {},
        '\n' => if (!allow_lf) return false,
        else => return false,
    };
    return true;
}

/// "whitespace node".
pub fn isWhitespaceNode(node: *Instance) !bool {
    if (!isText(node)) return false;
    var data = try textData(node);
    defer data.deinit(node.ctx.allocator);
    if (data.asSlice().len == 0) return true;
    const p = (try parent(node)) orelse return false;
    if (!isElement(p)) return false;
    return switch (whiteSpaceOf(p)) {
        .normal, .nowrap => isWhitespaceData(data.asSlice(), true),
        .pre_line => isWhitespaceData(data.asSlice(), false),
        else => false,
    };
}

/// "collapsed whitespace node".
pub fn isCollapsedWhitespaceNode(node: *Instance) !bool {
    // Step 1.
    if (!try isWhitespaceNode(node)) return false;
    // Step 2.
    if ((try nodeLength(node)) == 0) return true;
    // Steps 3-4.
    var ancestor = (try parent(node)) orelse return true;
    // Step 5.
    if (try hasDisplayNoneInclusiveAncestor(ancestor)) return true;
    // Step 6.
    while (!isBlockNode(ancestor)) {
        ancestor = (try parent(ancestor)) orelse break;
    }
    // Steps 7-8: backwards to a block boundary.
    var reference = node;
    while (isDescendantOf(reference, ancestor)) {
        reference = (try previousInTreeOrder(reference)) orelse break;
        if (isBlockNode(reference) or try isHtmlElementNamed(reference, "br")) return true;
        if ((isText(reference) and !try isWhitespaceNode(reference)) or try isHtmlElementNamed(reference, "img")) break;
    }
    // Steps 9-10: forwards to a block boundary.
    reference = node;
    while (isDescendantOf(reference, ancestor)) {
        reference = (try nextInTreeOrder(reference)) orelse return true;
        if (isBlockNode(reference) or try isHtmlElementNamed(reference, "br")) return true;
        if ((isText(reference) and !try isWhitespaceNode(reference)) or try isHtmlElementNamed(reference, "img")) break;
    }
    // Step 11.
    return false;
}

/// Whether a br is followed by a block boundary: nothing that would start a
/// new line after it before its block ends - no text that is not collapsed
/// whitespace, no img, no other br, no block node. Gecko's
/// HTMLEditUtils::IsBRElementFollowedByBlockBoundary.
fn brFollowedByBlockBoundary(br: *Instance) !bool {
    const block = (try blockNodeOf(br)) orelse return true;
    var current = try nextInTreeOrder(br);
    while (current) |c| {
        if (!isDescendantOf(c, block)) return true;
        if (isBlockNode(c)) return true;
        if (isElement(c) and displayIsNone(c)) {
            current = try nextSkippingChildren(c);
            continue;
        }
        if (try isHtmlElementNamed(c, "br")) return false;
        if (try isHtmlElementNamed(c, "img")) return false;
        if (isText(c) and !try isCollapsedWhitespaceNode(c)) return false;
        current = try nextInTreeOrder(c);
    }
    return true;
}

/// Whether a br follows a line boundary: nothing visible before it on its
/// line - its block's start, a block node or another br comes first.
/// Gecko's HTMLEditUtils::IsBRElementFollowingLineBoundary.
fn brFollowsLineBoundary(br: *Instance) !bool {
    const block = (try blockNodeOf(br)) orelse return true;
    var current = try previousInTreeOrder(br);
    while (current) |c| {
        if (c == block or !isDescendantOf(c, block)) return true;
        if (isBlockNode(c)) return true;
        if (try hasDisplayNoneInclusiveAncestor(c)) {
            current = try previousInTreeOrder(c);
            continue;
        }
        if (try isHtmlElementNamed(c, "br")) return true;
        if (try isHtmlElementNamed(c, "img")) return false;
        if (isText(c) and !try isCollapsedWhitespaceNode(c)) return false;
        current = try previousInTreeOrder(c);
    }
    return true;
}

/// "collapsed line break": a br that begins a line box with nothing else in
/// it. Without layout: a br followed by a block boundary (adding text after
/// it would add a line).
pub fn isCollapsedLineBreak(node: *Instance) !bool {
    if (!try isHtmlElementNamed(node, "br")) return false;
    return try brFollowedByBlockBoundary(node);
}

/// "extraneous line break": a br with no visual effect - removing it would
/// not change layout - except a br that is the sole child of an li. Without
/// layout: a br followed by a block boundary that does not itself follow a
/// line boundary (Gecko's unnecessary br), or one display: none hides.
pub fn isExtraneousLineBreak(node: *Instance) !bool {
    if (!try isHtmlElementNamed(node, "br")) return false;
    const p = try parent(node);
    if (p != null and (try isHtmlElementNamed(p.?, "li")) and (try childCount(p.?)) == 1) return false;
    if (try hasDisplayNoneInclusiveAncestor(node)) return true;
    if (!try brFollowedByBlockBoundary(node)) return false;
    return !try brFollowsLineBoundary(node);
}

/// "visible".
pub fn isVisible(node: *Instance) !bool {
    if (try hasDisplayNoneInclusiveAncestor(node)) return false;
    return try isVisibleIgnoringAncestors(node);
}

fn isVisibleIgnoringAncestors(node: *Instance) anyerror!bool {
    if (isElement(node) and displayIsNone(node)) return false;
    if (isBlockNode(node)) return true;
    if (isText(node) and !try isCollapsedWhitespaceNode(node)) return true;
    if (try isHtmlElementNamed(node, "img")) return true;
    if ((try isHtmlElementNamed(node, "br")) and !try isExtraneousLineBreak(node)) return true;
    var child = try firstChild(node);
    while (child) |c| : (child = try nextSibling(c)) {
        if (try isVisibleIgnoringAncestors(c)) return true;
    }
    return false;
}

pub fn isInvisible(node: *Instance) !bool {
    return !try isVisible(node);
}

/// "collapsed block prop".
pub fn isCollapsedBlockProp(node: *Instance) anyerror!bool {
    if ((try isCollapsedLineBreak(node)) and !try isExtraneousLineBreak(node)) return true;
    if (!isElement(node) or isBlockNode(node)) return false;
    var has_collapsed_block_prop_child = false;
    var child = try firstChild(node);
    while (child) |c| : (child = try nextSibling(c)) {
        const prop = try isCollapsedBlockProp(c);
        if (!(try isInvisible(c)) and !prop) return false;
        if (prop) has_collapsed_block_prop_child = true;
    }
    return has_collapsed_block_prop_child;
}

// ============================================================================
// Allowed children
// ============================================================================

const table_section_names = [_][]const u8{ "colgroup", "table", "tbody", "tfoot", "thead", "tr" };
const text_only_names = [_][]const u8{ "script", "style", "plaintext", "xmp" };
const heading_names = [_][]const u8{ "h1", "h2", "h3", "h4", "h5", "h6" };

/// A child for "allowed child": a node, or an element name.
pub const Child = union(enum) {
    node: *Instance,
    name: []const u8,
};

/// Whether `child` is an "allowed child" of `parent_node` (a node here;
/// the spec also takes a string parent).
pub fn isAllowedChild(child: Child, parent_node: *Instance) !bool {
    var parent_name_buffer: [64]u8 = undefined;
    const parent_is_html = try isHtmlElement(parent_node);
    const parent_name: ?[]const u8 = if (parent_is_html) try localNameInto(parent_node, &parent_name_buffer) else null;
    // Step 1: a table part takes no non-blank text.
    if (parent_name != null and nameIn(parent_name.?, &table_section_names)) {
        if (child == .node and isText(child.node)) {
            var data = try textData(child.node);
            defer data.deinit(child.node.ctx.allocator);
            for (data.asSlice()) |byte| switch (byte) {
                ' ', '\t', '\n', '\x0C', '\r' => {},
                else => return false,
            };
        }
    }
    // Step 2: script, style, plaintext and xmp take only text.
    if (parent_name != null and nameIn(parent_name.?, &text_only_names)) {
        if (child != .node or !isText(child.node)) return false;
    }
    // Step 3.
    if (child == .node and (isDocument(child.node) or isDocumentFragment(child.node) or isDocumentType(child.node))) return false;
    // Steps 4-5: a non-HTML-element node is allowed anywhere else.
    var child_name_buffer: [64]u8 = undefined;
    const child_name: []const u8 = switch (child) {
        .name => |n| n,
        .node => |n| if (try isHtmlElement(n)) ((try localNameInto(n, &child_name_buffer)) orelse return true) else return true,
    };
    // Step 6: the parent's ancestors matter for a, prohibited paragraph
    // children and headings.
    if (parent_is_html) {
        var current: ?*Instance = parent_node;
        while (current) |c| : (current = try parent(c)) {
            if (std.mem.eql(u8, child_name, "a") and try isHtmlElementNamed(c, "a")) return false;
            if (nameIn(child_name, &prohibited_paragraph_child_names) and try isElementWithInlineContents(c)) return false;
            if (nameIn(child_name, &heading_names) and try isHtmlElementIn(c, &heading_names)) return false;
        }
    }
    // Step 7: an Element or DocumentFragment parent that is not an HTML
    // element allows anything.
    if (!parent_is_html) return isElement(parent_node) or isDocumentFragment(parent_node);
    const pn = parent_name orelse return true;
    return allowedChildNames(pn, child_name);
}

/// Steps 9-14 of "allowed child", on names.
pub fn allowedChildNames(parent_name: []const u8, child_name: []const u8) bool {
    // Step 9.
    const Entry = struct { parents: []const []const u8, children: []const []const u8 };
    const step9 = [_]Entry{
        .{ .parents = &.{"colgroup"}, .children = &.{"col"} },
        .{ .parents = &.{"table"}, .children = &.{ "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr" } },
        .{ .parents = &.{ "tbody", "tfoot", "thead" }, .children = &.{ "td", "th", "tr" } },
        .{ .parents = &.{"tr"}, .children = &.{ "td", "th" } },
        .{ .parents = &.{"dl"}, .children = &.{ "dt", "dd" } },
        .{ .parents = &.{ "dir", "ol", "ul" }, .children = &.{ "dir", "li", "ol", "ul" } },
        .{ .parents = &.{"hgroup"}, .children = &heading_names },
    };
    for (step9) |entry| {
        if (nameIn(parent_name, entry.parents)) return nameIn(child_name, entry.children);
    }
    // Step 10.
    if (nameIn(child_name, &.{ "body", "caption", "col", "colgroup", "frame", "frameset", "head", "html", "tbody", "td", "tfoot", "th", "thead", "tr" })) return false;
    // Step 11.
    if ((std.mem.eql(u8, child_name, "dd") or std.mem.eql(u8, child_name, "dt")) and !std.mem.eql(u8, parent_name, "dl")) return false;
    // Step 12.
    if (std.mem.eql(u8, child_name, "li") and !std.mem.eql(u8, parent_name, "ol") and !std.mem.eql(u8, parent_name, "ul")) return false;
    // Step 13.
    const step13 = [_]Entry{
        .{ .parents = &.{"a"}, .children = &.{"a"} },
        .{ .parents = &.{ "dd", "dt" }, .children = &.{ "dd", "dt" } },
        .{ .parents = &heading_names, .children = &heading_names },
        .{ .parents = &.{"li"}, .children = &.{"li"} },
        .{ .parents = &.{"nobr"}, .children = &.{"nobr"} },
        .{ .parents = &inline_contents_names, .children = &prohibited_paragraph_child_names },
        .{ .parents = &.{ "td", "th" }, .children = &.{ "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr" } },
    };
    for (step13) |entry| {
        if (nameIn(parent_name, entry.parents) and nameIn(child_name, entry.children)) return false;
    }
    // Step 14.
    return true;
}

// ============================================================================
// Block boundary points, line breaks around a node, equivalent points
// ============================================================================

/// "block boundary point": (node, offset) where node is a block node and
/// offset is 0 or node's length, or the point is just before or after a
/// block node child, or just after a br ("Block-extending a range").
pub fn isBlockBoundaryPoint(point: Point) !bool {
    const node = point.node;
    const offset = point.offset;
    if (isBlockNode(node) and (offset == 0 or offset == try nodeLength(node))) return true;
    if (try childAt(node, offset)) |child| {
        if (isBlockNode(child)) return true;
    }
    if (try childBefore(node, offset)) |child| {
        if (isBlockNode(child) or try isHtmlElementNamed(child, "br")) return true;
    }
    return false;
}

/// "follows a line break".
pub fn followsLineBreak(node_in: *Instance) !bool {
    var node = node_in;
    // Step 1.
    var offset: u32 = 0;
    // Step 2.
    while (!try isBlockBoundaryPoint(.{ .node = node, .offset = offset })) {
        // Step 2.1.
        if (try childBefore(node, offset)) |child| {
            if (try isVisible(child)) return false;
        }
        // Step 2.2.
        if (offset == 0 or !try hasChildren(node)) {
            offset = try indexOf(node);
            node = (try parent(node)) orelse return true;
        } else {
            // Step 2.3.
            node = (try childBefore(node, offset)) orelse return true;
            offset = try nodeLength(node);
        }
    }
    // Step 3.
    return true;
}

/// "precedes a line break".
pub fn precedesLineBreak(node_in: *Instance) !bool {
    var node = node_in;
    // Step 1.
    var offset: u32 = try nodeLength(node);
    // Step 2.
    while (!try isBlockBoundaryPoint(.{ .node = node, .offset = offset })) {
        // Step 2.1.
        if (try childAt(node, offset)) |child| {
            if (try isVisible(child)) return false;
        }
        // Step 2.2.
        if (offset == try nodeLength(node) or !try hasChildren(node)) {
            offset = (try indexOf(node)) + 1;
            node = (try parent(node)) orelse return true;
        } else {
            // Step 2.3.
            node = (try childAt(node, offset)) orelse return true;
            offset = 0;
        }
    }
    // Step 3.
    return true;
}

/// "next equivalent point".
pub fn nextEquivalentPoint(point: Point) !?Point {
    const node = point.node;
    const offset = point.offset;
    // Step 1.
    if ((try nodeLength(node)) == 0) return null;
    // Step 3.
    if (offset == try nodeLength(node)) {
        if (try parent(node)) |p| {
            if (isInlineNode(node)) return .{ .node = p, .offset = 1 + try indexOf(node) };
        }
    }
    // Step 5.
    if (try childAt(node, offset)) |child| {
        if ((try nodeLength(child)) != 0 and isInlineNode(child)) return .{ .node = child, .offset = 0 };
    }
    // Step 7.
    return null;
}

/// "previous equivalent point".
pub fn previousEquivalentPoint(point: Point) !?Point {
    const node = point.node;
    const offset = point.offset;
    // Step 1.
    if ((try nodeLength(node)) == 0) return null;
    // Step 2.
    if (offset == 0) {
        if (try parent(node)) |p| {
            if (isInlineNode(node)) return .{ .node = p, .offset = try indexOf(node) };
        }
    }
    // Step 3.
    if (try childBefore(node, offset)) |child| {
        if ((try nodeLength(child)) != 0 and isInlineNode(child)) return .{ .node = child, .offset = try nodeLength(child) };
    }
    // Step 4.
    return null;
}

/// "first equivalent point".
pub fn firstEquivalentPoint(point_in: Point) !Point {
    var point = point_in;
    while (try previousEquivalentPoint(point)) |previous| point = previous;
    return point;
}

/// "last equivalent point".
pub fn lastEquivalentPoint(point_in: Point) !Point {
    var point = point_in;
    while (try nextEquivalentPoint(point)) |next| point = next;
    return point;
}

/// Whether `data[0..offset]` (UTF-16 units) is all collapsible white-space
/// under `white_space`: spaces, tabs and carriage returns, and line feeds
/// unless segment breaks are preserved; nothing when spaces are preserved.
fn unitsAreCollapsibleWhitespace(data: []const u8, from: u32, to: u32, white_space: WhiteSpace) bool {
    if (white_space.preservesSpaces()) return false;
    const start = byteOffsetOfUnits(data, from);
    const end = byteOffsetOfUnits(data, to);
    if (start >= end) return false;
    for (data[start..end]) |byte| switch (byte) {
        ' ', '\t', '\r' => {},
        '\n' => if (white_space.preservesNewlines()) return false,
        else => return false,
    };
    return true;
}

/// Whether the UTF-16 units `from..to` of the Text node's data are all
/// collapsible white-space under the white-space that applies to it.
pub fn textIsCollapsibleWhitespace(node: *Instance, from: u32, to: u32) !bool {
    var data = try textData(node);
    defer data.deinit(node.ctx.allocator);
    return unitsAreCollapsibleWhitespace(data.asSlice(), from, to, try whiteSpaceAround(node));
}

// ============================================================================
// UTF-16 code units over UTF-8 data
// ============================================================================

/// The UTF-16 code unit at `index` of the UTF-8 `data`, or null past its
/// end. A supplementary code point yields its high then low surrogate.
pub fn codeUnitAt(data: []const u8, index: u32) ?u16 {
    var units: u32 = 0;
    var i: usize = 0;
    while (i < data.len) {
        const len = std.unicode.utf8ByteSequenceLength(data[i]) catch 1;
        if (i + len > data.len) return null;
        const code_point = std.unicode.utf8Decode(data[i .. i + len]) catch 0xFFFD;
        if (code_point >= 0x10000) {
            if (units == index) return @intCast(0xD800 + ((code_point - 0x10000) >> 10));
            if (units + 1 == index) return @intCast(0xDC00 + ((code_point - 0x10000) & 0x3FF));
            units += 2;
        } else {
            if (units == index) return @intCast(code_point);
            units += 1;
        }
        i += len;
    }
    return null;
}

/// The code point whose UTF-16 encoding starts (or, for a low surrogate,
/// continues) at unit `index` of the UTF-8 `data`, or null past its end.
pub fn codePointAt(data: []const u8, index: u32) ?u21 {
    var units: u32 = 0;
    var i: usize = 0;
    while (i < data.len) {
        const len = std.unicode.utf8ByteSequenceLength(data[i]) catch 1;
        if (i + len > data.len) return null;
        const code_point = std.unicode.utf8Decode(data[i .. i + len]) catch 0xFFFD;
        const width: u32 = if (code_point >= 0x10000) 2 else 1;
        if (index >= units and index < units + width) return code_point;
        units += width;
        i += len;
    }
    return null;
}

/// The UTF-16 length of `data`.
pub fn utf16Length(data: []const u8) u32 {
    var units: u32 = 0;
    var i: usize = 0;
    while (i < data.len) {
        const len = std.unicode.utf8ByteSequenceLength(data[i]) catch 1;
        units += if (len == 4) 2 else 1;
        i += len;
    }
    return units;
}

/// The byte offset in `data` of UTF-16 offset `units` (clamped to its end).
pub fn byteOffsetOfUnits(data: []const u8, units: u32) usize {
    var counted: u32 = 0;
    var i: usize = 0;
    while (i < data.len and counted < units) {
        const len = std.unicode.utf8ByteSequenceLength(data[i]) catch 1;
        counted += if (len == 4) 2 else 1;
        i += len;
    }
    return i;
}

/// Whether a UTF-16 code unit is a space (0x0020) or non-breaking space.
pub fn isSpaceOrNbsp(unit: u16) bool {
    return unit == 0x20 or unit == 0xA0;
}

test "allowed child names" {
    try std.testing.expect(allowedChildNames("p", "span"));
    try std.testing.expect(!allowedChildNames("p", "div"));
    try std.testing.expect(!allowedChildNames("span", "p"));
    try std.testing.expect(allowedChildNames("div", "p"));
    try std.testing.expect(allowedChildNames("ul", "li"));
    try std.testing.expect(!allowedChildNames("div", "li"));
    try std.testing.expect(!allowedChildNames("table", "span"));
    try std.testing.expect(allowedChildNames("td", "span"));
    try std.testing.expect(!allowedChildNames("td", "tr"));
    try std.testing.expect(!allowedChildNames("h1", "h2"));
    try std.testing.expect(!allowedChildNames("a", "a"));
    try std.testing.expect(!allowedChildNames("dl", "p"));
    try std.testing.expect(!allowedChildNames("div", "body"));
}

test "UTF-16 code units over UTF-8" {
    try std.testing.expectEqual(@as(?u16, 'f'), codeUnitAt("foo", 0));
    try std.testing.expectEqual(@as(?u16, 0xA0), codeUnitAt("a\u{A0}b", 1));
    try std.testing.expectEqual(@as(?u16, 0xD83D), codeUnitAt("\u{1F600}x", 0));
    try std.testing.expectEqual(@as(?u16, 0xDE00), codeUnitAt("\u{1F600}x", 1));
    try std.testing.expectEqual(@as(?u16, 'x'), codeUnitAt("\u{1F600}x", 2));
    try std.testing.expectEqual(@as(?u16, null), codeUnitAt("ab", 2));
    try std.testing.expectEqual(@as(u32, 3), utf16Length("\u{1F600}x"));
    try std.testing.expectEqual(@as(usize, 4), byteOffsetOfUnits("\u{1F600}x", 2));
    try std.testing.expectEqual(@as(usize, 1), byteOffsetOfUnits("a\u{A0}b", 1));
    try std.testing.expectEqual(@as(usize, 3), byteOffsetOfUnits("a\u{A0}b", 2));
}
