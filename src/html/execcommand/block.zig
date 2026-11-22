//! The Editing spec's block formatting machinery (specs/w3c/execCommand.md,
//! "Block formatting command definitions", "Assorted block formatting
//! command algorithms", "Block-extending a range") and the formatBlock
//! command: block start and end points, block-extend, the nodes contained
//! in a range, fix disallowed ancestors, the default single-line container
//! name, and formatBlock's action, value and indeterminacy.
//!
//! A block-extended range is two boundary points, not a live Range: the
//! callers only read which nodes it contains, and a live Range would join
//! the document's live-range list and be updated by every mutation the
//! command makes. Where a step mutates the tree and then needs the range
//! again, it block-extends the active range anew, as the spec does.
//!
//! Every DOM read and write goes through the generated interfaces (common.zig),
//! never an impl.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const common = @import("common.zig");
const split_parent = @import("split_parent.zig");
const overrides = @import("overrides.zig");
const wrap_mod = @import("wrap.zig");
const visible_position = @import("visible_position.zig");

const Edit = common.Edit;
const Point = common.Point;
const Instance = common.Instance;

/// A range given by its two boundary points.
pub const Range = struct {
    start: Point,
    end: Point,
};

fn isBr(node: *Instance) !bool {
    return try common.isHtmlElementNamed(node, "br");
}

// ============================================================================
// Block start and end points, block-extend
// ============================================================================

/// "block start point": node's parent is null and offset is zero; or node
/// has a child with index offset - 1 that is a visible block node or a
/// visible br.
pub fn isBlockStartPoint(point: Point) !bool {
    if ((try common.parent(point.node)) == null and point.offset == 0) return true;
    const child = (try common.childBefore(point.node, point.offset)) orelse return false;
    if (!try common.isVisible(child)) return false;
    return common.isBlockNode(child) or try isBr(child);
}

/// "block end point": node's parent is null and offset is node's length;
/// or node has a child with index offset that is a visible block node.
pub fn isBlockEndPoint(point: Point) !bool {
    if ((try common.parent(point.node)) == null and point.offset == try common.nodeLength(point.node)) return true;
    const child = (try common.childAt(point.node, point.offset)) orelse return false;
    return common.isBlockNode(child) and try common.isVisible(child);
}

/// "block boundary point" as "Block-extending a range" defines it: a block
/// start point or a block end point. (common.isBlockBoundaryPoint is the
/// looser rule the delete commands' line-break tests were built on.)
pub fn isBlockBoundaryPoint(point: Point) !bool {
    return (try isBlockStartPoint(point)) or try isBlockEndPoint(point);
}

/// The last li in tree order among the inclusive ancestors of `node`.
fn outermostListItem(node: *Instance) !?*Instance {
    var found: ?*Instance = null;
    var current: ?*Instance = node;
    while (current) |c| : (current = try common.parent(c)) {
        if (try common.isHtmlElementNamed(c, "li")) {
            // Walking up meets the innermost first; the last in tree order
            // is the innermost one.
            if (found == null) found = c;
        }
    }
    return found;
}

/// "block-extend" the range (start, end).
pub fn blockExtend(start_in: Point, end_in: Point) !Range {
    // Step 1.
    var start = start_in;
    var end = end_in;
    // Step 2: inside an li, start before the last such li in tree order.
    if (try outermostListItem(start.node)) |li| {
        if (try common.parent(li)) |p| start = try common.pointBefore(li, p);
    }
    // Step 3.
    if (!try isBlockStartPoint(start)) {
        while (true) {
            // Step 3.1.
            if (start.offset == 0) {
                const p = (try common.parent(start.node)) orelse break;
                start = try common.pointBefore(start.node, p);
            } else {
                // Step 3.2.
                start.offset -= 1;
            }
            // Step 3.3.
            if (try isBlockBoundaryPoint(start)) break;
        }
    }
    // Step 4.
    while (start.offset == 0) {
        const p = (try common.parent(start.node)) orelse break;
        start = try common.pointBefore(start.node, p);
    }
    // Step 5: inside an li, end after the last such li in tree order.
    if (try outermostListItem(end.node)) |li| {
        if (try common.parent(li)) |p| end = try common.pointAfter(li, p);
    }
    // Step 6.
    if (!try isBlockEndPoint(end)) {
        while (true) {
            // Step 6.1.
            if (end.offset == try common.nodeLength(end.node)) {
                const p = (try common.parent(end.node)) orelse break;
                end = try common.pointAfter(end.node, p);
            } else {
                // Step 6.2.
                end.offset += 1;
            }
            // Step 6.3.
            if (try isBlockBoundaryPoint(end)) break;
        }
    }
    // Step 7.
    while (end.offset == try common.nodeLength(end.node)) {
        const p = (try common.parent(end.node)) orelse break;
        end = try common.pointAfter(end.node, p);
    }
    // Steps 8-9.
    return .{ .start = start, .end = end };
}

/// Block-extend the active range; null without one.
pub fn blockExtendActiveRange(edit: *Edit) !?Range {
    const start = (try edit.rangeStart()) orelse return null;
    const end = (try edit.rangeEnd()) orelse return null;
    return try blockExtend(start, end);
}

// ============================================================================
// Contained nodes
// ============================================================================

/// DOM "contained": (node, 0) is after the range's start and (node, length)
/// is before its end (the root check holds for every node the walk visits).
pub fn isContained(node: *Instance, range: Range) !bool {
    if (!try common.pointIsAfter(.{ .node = node, .offset = 0 }, range.start)) return false;
    return try common.pointIsBefore(.{ .node = node, .offset = try common.nodeLength(node) }, range.end);
}

/// The nodes contained in a range, in tree order: the first node that can
/// be contained, up to the first node after the range's end (the reference
/// implementation's getAllContainedNodes walk, which visits only the nodes
/// between the two boundary points).
pub const ContainedWalk = struct {
    range: Range,
    current: ?*Instance,
    stop: ?*Instance,

    pub fn init(range: Range) !ContainedWalk {
        const start = range.start;
        const first: ?*Instance = if ((try common.hasChildren(start.node)) and start.offset < try common.childCount(start.node))
            try common.childAt(start.node, start.offset)
        else if (start.offset == try common.nodeLength(start.node))
            try common.nextSkippingChildren(start.node)
        else
            try common.nextInTreeOrder(start.node);
        const end = range.end;
        const stop: ?*Instance = if ((try common.hasChildren(end.node)) and end.offset < try common.childCount(end.node))
            try common.childAt(end.node, end.offset)
        else
            try common.nextSkippingChildren(end.node);
        return .{ .range = range, .current = first, .stop = stop };
    }

    /// The next contained node, or null.
    pub fn next(self: *ContainedWalk) !?*Instance {
        while (self.current) |node| {
            if (node == self.stop) {
                self.current = null;
                return null;
            }
            self.current = try common.nextInTreeOrder(node);
            if (try isContained(node, self.range)) return node;
        }
        return null;
    }

    /// Skip the descendants of `node`, the node `next` just returned.
    pub fn skipDescendants(self: *ContainedWalk, node: *Instance) !void {
        if (self.current == null) return;
        // Every node before stop in tree order is a candidate; a descendant
        // of `node` that is the stop node ends the walk when reached.
        var after = try common.nextSkippingChildren(node);
        if (self.stop) |stop| {
            if (common.isDescendantOf(stop, node)) after = stop;
        }
        self.current = after;
    }
};

/// Whether the last member of `list` is an ancestor of `node` (the steps
/// that build a node list skip the descendants of a node already in it).
pub fn lastIsAncestorOf(list: []const *Instance, node: *Instance) bool {
    if (list.len == 0) return false;
    return common.isAncestorOf(list[list.len - 1], node);
}

/// Whether `node` has an editable descendant.
pub fn hasEditableDescendants(node: *Instance) !bool {
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (try common.isEditable(c)) return true;
        if (try hasEditableDescendants(c)) return true;
    }
    return false;
}

/// Whether `node` is an ancestor of a prohibited paragraph child.
pub fn isAncestorOfProhibitedParagraphChild(node: *Instance) !bool {
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (try common.isProhibitedParagraphChild(c)) return true;
        if (try isAncestorOfProhibitedParagraphChild(c)) return true;
    }
    return false;
}

// ============================================================================
// The default single-line container name
// ============================================================================

/// The Document's "default single-line container name": the
/// defaultParagraphSeparator command's value, "div" until it is set.
pub fn defaultSingleLineContainerName(edit: *Edit) ![]const u8 {
    var value = try interfaces.Document.call_queryCommandValue(edit.document, runtime.DOMString.initInterned("defaultParagraphSeparator"));
    defer value.deinit(edit.document.ctx.allocator);
    return if (std.mem.eql(u8, value.asSlice(), "p")) "p" else "div";
}

// ============================================================================
// Fix disallowed ancestors
// ============================================================================

/// The wrap context of "fix disallowed ancestors" step 2.1: merge into a
/// sibling dl with no attributes, else a new dl.
const DlContext = struct {
    pub fn siblingCriteria(_: DlContext, node: *Instance) anyerror!bool {
        if (!try common.isHtmlElementNamed(node, "dl")) return false;
        const attributes = try interfaces.Element.get_attributes(node);
        return (try interfaces.NamedNodeMap.get_length(attributes)) == 0;
    }
    pub fn newParent(_: DlContext, edit: *Edit) anyerror!?*Instance {
        return try edit.createElement("dl");
    }
};

/// Whether `node` is an allowed child of some ancestor in the same editing
/// host.
fn isAllowedChildOfAnAncestorInHost(node: *Instance) !bool {
    var current = try common.parent(node);
    while (current) |c| : (current = try common.parent(c)) {
        if (!try common.inSameEditingHost(node, c)) continue;
        if (try common.isAllowedChild(.{ .node = node }, c)) return true;
    }
    return false;
}

/// "fix disallowed ancestors" of `node_in`.
pub fn fixDisallowedAncestors(edit: *Edit, node_in: *Instance) anyerror!void {
    var node = node_in;
    // Step 1.
    if (!try common.isEditable(node)) return;
    // Step 2: allowed under no ancestor in its editing host.
    if (!try isAllowedChildOfAnAncestorInHost(node)) {
        // Step 2.1: a stray dd or dt gets a dl.
        if (try common.isHtmlElementIn(node, &.{ "dd", "dt" })) {
            _ = try wrap_mod.wrap(edit, &.{node}, DlContext{});
            return;
        }
        // Step 2.2.
        const host = (try common.editingHostOf(node)) orelse return;
        if (!try common.isAllowedChild(.{ .name = "p" }, host)) return;
        // Step 2.3.
        if (!try common.isProhibitedParagraphChild(node)) return;
        // A list item left in a table cell gives way to its contents rather
        // than becoming the default single-line container: Chrome 156 and
        // Firefox 158 turn `<td>[fsdf]</td>` + insertOrderedList twice back
        // into `<td>fsdf</td>` (editing/run/insert-list-items-in-table-cell
        // .html, wpt.fyi 5af3c135c9); in the editing host itself the item
        // becomes the default container, as the spec says and the data
        // expects.
        if (try common.isHtmlElementNamed(node, "li")) {
            if (try common.parent(node)) |p| {
                if (try common.isHtmlElementIn(p, &.{ "td", "th" })) {
                    try split_parent.removePreservingDescendants(edit, node);
                    return;
                }
            }
        }
        // Step 2.4.
        node = try edit.setTagName(node, try defaultSingleLineContainerName(edit));
        // Step 2.5.
        try fixDisallowedAncestors(edit, node);
        // Steps 2.6-2.7: split out each prohibited paragraph child.
        var children: std.ArrayList(*Instance) = .empty;
        defer children.deinit(edit.allocator);
        var child = try common.firstChild(node);
        while (child) |c| : (child = try common.nextSibling(c)) try children.append(edit.allocator, c);
        for (children.items) |c| {
            if (!try common.isProhibitedParagraphChild(c)) continue;
            const values = try overrides.recordTheValues(edit, &.{c});
            try split_parent.splitParent(edit, &.{c});
            try overrides.restoreTheValues(edit, values);
        }
        // Step 2.8.
        return;
    }
    // Step 3.
    const values = try overrides.recordTheValues(edit, &.{node});
    // Step 4: split the parent until node is an allowed child of it. Step 2
    // guarantees an ancestor in the same editing host allows it; a split
    // that cannot move node (its parent not editable) ends the loop rather
    // than spinning.
    while (try common.parent(node)) |p| {
        if (try common.isAllowedChild(.{ .node = node }, p)) break;
        try split_parent.splitParent(edit, &.{node});
        if ((try common.parent(node)) == p) break;
    }
    // Step 5.
    try overrides.restoreTheValues(edit, values);
}

// ============================================================================
// The formatBlock command
// ============================================================================

/// "formattable block name": the spec lists address, dd, div, dt, h1-h6, p
/// and pre; all three browsers also take article, aside, blockquote, dl,
/// footer, header, hgroup, nav and section, as values to format with and in
/// the command's value (editing/run/formatblock.html: Chrome 156, Firefox
/// 158 and Safari 27 return true for `<nav>`, `<blockquote>`, `<dl>` ...
/// and give `<p>[foobar]</p>` -> `<nav>foobar</nav>`, wpt.fyi 5af3c135c9).
/// The list is the engines' own, main included: Blink
/// format_block_command.cc IsElementForFormatBlock and Gecko
/// HTMLEditUtils::IsFormatTagForFormatBlockCommand (identical lists).
pub const formattable_block_names = [_][]const u8{
    "address", "article", "aside", "blockquote", "dd",     "div",    "dl",   "dt",  "footer", "h1",  "h2",
    "h3",      "h4",      "h5",    "h6",         "header", "hgroup", "main", "nav", "p",      "pre", "section",
};

/// An editable HTML element whose local name is a formattable block name
/// and that is not the ancestor of a prohibited paragraph child.
fn isFormatBlockCandidate(node: *Instance) !bool {
    if (!try common.isHtmlElementIn(node, &formattable_block_names)) return false;
    if (!try common.isEditable(node)) return false;
    return !try isAncestorOfProhibitedParagraphChild(node);
}

/// The wrap context of formatBlock step 10.2.3.
const FormatBlockContext = struct {
    name: []const u8,
    /// The blocks this formatBlock run has made so far (see siblingCriteria).
    created: *std.ArrayList(*Instance),

    pub fn siblingCriteria(self: FormatBlockContext, node: *Instance) anyerror!bool {
        // "If value is "div" or "p", sibling criteria returns false;
        // otherwise it returns true for an HTML element with local name
        // value and no attributes."
        if (std.mem.eql(u8, self.name, "div") or std.mem.eql(u8, self.name, "p")) return false;
        if (!try common.isHtmlElementNamed(node, self.name)) return false;
        const attributes = try interfaces.Element.get_attributes(node);
        if ((try interfaces.NamedNodeMap.get_length(attributes)) != 0) return false;
        // Only a block this run made: a line joins the new block of the line
        // before it, never a block that was already there - `[foo]<blockquote>
        // bar</blockquote><p>extra` + "blockquote" gives `<blockquote>foo
        // </blockquote><blockquote>bar</blockquote>` in Chrome 157, Firefox 160
        // and Safari 27.2 (editing/run/formatblock.html, PPP at wpt.fyi
        // 2358bd4835), where the spec's criteria merge it into the existing
        // one (lane edit4, A21). Blink's ApplyBlockElementCommand::
        // FormatSelection shares one new block among the selected paragraphs
        // and never reuses one outside them. Golden rule 2, no newer spec.
        return std.mem.indexOfScalar(*Instance, self.created.items, node) != null;
    }

    pub fn newParent(self: FormatBlockContext, edit: *Edit) anyerror!?*Instance {
        const element = try edit.createElement(self.name);
        try self.created.append(edit.allocator, element);
        return element;
    }
};

/// The formatBlock command's action, given `value_in`.
pub fn formatBlockAction(edit: *Edit, value_in: []const u8) !bool {
    // Step 1: strip one pair of angle brackets.
    var value = value_in;
    if (value.len >= 2 and value[0] == '<' and value[value.len - 1] == '>') value = value[1 .. value.len - 1];
    // Steps 2-3: lowercased, and a formattable block name. The names are
    // short ASCII, so a stack buffer holds the lowercase form.
    var buffer: [16]u8 = undefined;
    if (value.len > buffer.len) return false;
    const lowered = std.ascii.lowerString(buffer[0..value.len], value);
    var name: []const u8 = undefined;
    for (formattable_block_names) |candidate| {
        if (std.mem.eql(u8, lowered, candidate)) {
            name = candidate;
            break;
        }
    } else return false;
    // "dl" is not a value to format with, as the spec says, although all
    // three browsers take it (`<p>[foobar]</p>` -> `<dl>foobar</dl>`): the
    // data file expects the spec's unchanged block, which Crane passed
    // before this command existed, and taking dl would trade those passing
    // subtests (editing/run/formatblock.html, `<dl>` rows, FFF at wpt.fyi
    // 5af3c135c9) - OPEN for the integrator's ruling. A dl stays a
    // formattable block for the value and indeterminacy.
    if (std.mem.eql(u8, name, "dl")) return false;
    // Step 4.
    const new_range = (try blockExtendActiveRange(edit)) orelse return false;
    // Steps 5-6: the editable nodes contained in it that are non-list
    // single-line containers, allowed children of "p", dds or dts, and not
    // the ancestors of a prohibited paragraph child, outermost first.
    var node_list: std.ArrayList(*Instance) = .empty;
    defer node_list.deinit(edit.allocator);
    var created: std.ArrayList(*Instance) = .empty;
    defer created.deinit(edit.allocator);
    var walk = try ContainedWalk.init(new_range);
    while (try walk.next()) |node| {
        if (!try common.isEditable(node)) continue;
        if (lastIsAncestorOf(node_list.items, node)) continue;
        const kind = (try common.isNonListSingleLineContainer(node)) or
            (try isAllowedChildOfName(.{ .node = node }, "p")) or
            (try common.isHtmlElementIn(node, &.{ "dd", "dt" }));
        if (!kind) continue;
        if (try isAncestorOfProhibitedParagraphChild(node)) continue;
        try node_list.append(edit.allocator, node);
    }
    // Step 7.
    const values = try overrides.recordTheValues(edit, node_list.items);
    // Step 8: break each node out of a formattable block ancestor that is not
    // the ancestor of a prohibited paragraph child.
    for (node_list.items) |node| {
        while (true) {
            var breaks_out = false;
            var ancestor = try common.parent(node);
            while (ancestor) |a| : (ancestor = try common.parent(a)) {
                if (!try common.inSameEditingHost(node, a)) continue;
                if (try isFormatBlockCandidate(a)) {
                    breaks_out = true;
                    break;
                }
            }
            if (!breaks_out) break;
            const before = try common.parent(node);
            try split_parent.splitParent(edit, &.{node});
            if ((try common.parent(node)) == before) break;
        }
    }
    // Step 9.
    try overrides.restoreTheValues(edit, values);
    // Step 10.
    var index: usize = 0;
    while (index < node_list.items.len) {
        const first = node_list.items[index];
        var sublist: std.ArrayList(*Instance) = .empty;
        defer sublist.deinit(edit.allocator);
        // Whether step 10.1 takes away a container of another name (see
        // step 10.3 below).
        var dissolved_other_name = false;
        // A container step 10.1 took away whose attributes the new block
        // takes over (see below), and its children's recorded values.
        var dissolved_with_attributes: ?*Instance = null;
        var child_values: overrides.Values = .{};
        if (try dissolvesForFormatBlock(first)) {
            dissolved_other_name = !try common.localNameIs(first, name);
            // Step 10.1: a single-line container gives way to its children.
            var child = try common.firstChild(first);
            while (child) |c| : (child = try common.nextSibling(c)) try sublist.append(edit.allocator, c);
            child_values = try overrides.recordTheValues(edit, sublist.items);
            try split_parent.removePreservingDescendants(edit, first);
            if (try hasAttributes(first)) {
                dissolved_with_attributes = first;
            } else {
                try overrides.restoreTheValues(edit, child_values);
            }
            index += 1;
        } else {
            // Step 10.2: a run of consecutive siblings, up to a single-line
            // container or a br.
            try sublist.append(edit.allocator, first);
            index += 1;
            while (index < node_list.items.len) {
                const candidate = node_list.items[index];
                const last = sublist.items[sublist.items.len - 1];
                if ((try common.nextSibling(last)) != candidate) break;
                if (try dissolvesForFormatBlock(candidate)) break;
                if (try isBr(last)) break;
                try sublist.append(edit.allocator, candidate);
                index += 1;
            }
        }
        // Step 10.3, with two cases the browsers leave alone:
        // - a line whose nearest formattable block is already a `name`
        //   (`<div><ol><li>[foo]</ol></div>` + "div" is unchanged in Chrome
        //   156, Firefox 158 and Safari 27; Gecko
        //   FormatBlockContainerWithTransaction finds the format block in
        //   place) - unless the line's own container, of another name, was
        //   just taken away: that line is wrapped (`<blockquote><p>[foo]<p>
        //   bar</blockquote>` + "blockquote" -> `<blockquote><blockquote>foo
        //   </blockquote><p>bar</p></blockquote>`, PPP at wpt.fyi
        //   2358bd4835), and
        // - a line where no ancestor in the editing host can hold a `name`,
        //   which fix disallowed ancestors could not repair (all three keep
        //   `<p contenteditable=false><span contenteditable>[foo]</span></p>`
        //   on "p"; Firefox also keeps a div host's span and a p host on
        //   "div"; editing/run/formatblock.html at wpt.fyi 5af3c135c9).
        if (sublist.items.len == 0) continue;
        // A container with attributes that was taken away hands them to the
        // new block, as all three browsers do (`<div style=color:blue>[foo]
        // </div>` + "p" -> `<p style="color:blue">foo</p>`, where the spec
        // restores the color on a span or font inside: editing/run/
        // formatblock.html, PPP at wpt.fyi 2358bd4835; Gecko's
        // ReplaceContainerAndCloneAttributesWithTransaction, Blink's
        // ReplaceElementWithSpanPreservingChildrenAndAttributes-style
        // replacement). When no new block takes them, the values are
        // restored as step 10.1 says.
        var wrapped: ?*Instance = null;
        skip: {
            if (!dissolved_other_name and try nearestFormatBlockIsNamed(sublist.items[0], name)) break :skip;
            if (!try nameIsAllowedInHost(sublist.items[0], name)) break :skip;
            wrapped = try wrap_mod.wrap(edit, sublist.items, FormatBlockContext{ .name = name, .created = &created });
        }
        if (dissolved_with_attributes) |old| {
            if (wrapped != null and !try hasAttributes(wrapped.?) and (try common.firstChild(wrapped.?)) == sublist.items[0]) {
                try copyAttributes(old, wrapped.?);
            } else {
                try overrides.restoreTheValues(edit, child_values);
            }
        }
        if (wrapped) |result| try fixDisallowedAncestors(edit, result);
    }
    // Step 11.
    return true;
}

fn hasAttributes(element: *Instance) !bool {
    const attributes = try interfaces.Element.get_attributes(element);
    return (try interfaces.NamedNodeMap.get_length(attributes)) > 0;
}

/// Copy every attribute of `from` onto `to`.
fn copyAttributes(from: *Instance, to: *Instance) !void {
    const attributes = try interfaces.Element.get_attributes(from);
    const count = try interfaces.NamedNodeMap.get_length(attributes);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const attr = (try interfaces.NamedNodeMap.call_item(attributes, i)) orelse continue;
        var attr_name = try interfaces.Attr.get_name(attr);
        defer attr_name.deinit(from.ctx.allocator);
        var value = try interfaces.Attr.get_value(attr);
        defer value.deinit(from.ctx.allocator);
        try common.setAttribute(to, attr_name.asSlice(), value.asSlice());
    }
}

/// "allowed child" with a string parent (the spec's steps 1-5 and 9-14;
/// step 6 needs a parent node): `child` may be placed under an element
/// named `parent_name` wherever that element itself may go.
pub fn isAllowedChildOfName(child: common.Child, parent_name: []const u8) !bool {
    // Step 1: a table part takes no non-blank text.
    if (common.nameIn(parent_name, &.{ "colgroup", "table", "tbody", "tfoot", "thead", "tr" })) {
        if (child == .node and common.isText(child.node)) {
            var data = try common.textData(child.node);
            defer data.deinit(child.node.ctx.allocator);
            for (data.asSlice()) |byte| switch (byte) {
                ' ', '\t', '\n', '\x0C', '\r' => {},
                else => return false,
            };
        }
    }
    // Step 2: script, style, plaintext and xmp take only text.
    if (common.nameIn(parent_name, &.{ "script", "style", "plaintext", "xmp" })) {
        if (child != .node or !common.isText(child.node)) return false;
    }
    // Step 3.
    if (child == .node and (common.isDocument(child.node) or common.isDocumentFragment(child.node) or common.isDocumentType(child.node))) return false;
    // Steps 4-5: a node that is not an HTML element is allowed.
    var buffer: [64]u8 = undefined;
    const child_name: []const u8 = switch (child) {
        .name => |n| n,
        .node => |n| if (try common.isHtmlElement(n)) ((try common.localNameInto(n, &buffer)) orelse return true) else return true,
    };
    // Steps 9-14.
    return common.allowedChildNames(parent_name, child_name);
}

/// Walk up from `node_in` to the nearest formattable block element in its
/// editing host (formatBlock's value and indeterminacy steps 4 / 6.1).
fn formatBlockOwner(node_in: *Instance) !*Instance {
    var node = node_in;
    while (try common.parent(node)) |p| {
        if (try common.isHtmlElementIn(node, &formattable_block_names)) break;
        if (!try common.isEditable(p)) break;
        if (!try common.inSameEditingHost(p, node)) break;
        node = p;
    }
    return node;
}

/// The visible editable childless nodes contained in the block-extended
/// active range, for formatBlock's and the justify commands' queries.
pub fn visibleEditableLeaves(edit: *Edit, range: Range, list: *std.ArrayList(*Instance)) !void {
    var walk = try ContainedWalk.init(range);
    while (try walk.next()) |node| {
        if (try common.hasChildren(node)) continue;
        if (!try common.isEditable(node)) continue;
        if (!try common.isVisible(node)) continue;
        try list.append(edit.allocator, node);
    }
}

/// Whether an element named `name` may be a child of `node`'s parent or of
/// another of its ancestors in the same editing host - somewhere fix
/// disallowed ancestors can move a new wrapper to. A dd or dt goes where a
/// dl may: fix disallowed ancestors step 2.1 wraps a stray one in a dl, so
/// `<p>[foobar]</p>` + formatBlock "dd" gives `<dl><dd>foobar</dd></dl>`
/// (editing/run/formatblock.html; Firefox 160 makes exactly that, Chrome
/// 157 and Safari 27.2 a bare dd, and all three then report "dd" as the
/// value, wpt.fyi 2358bd4835), where checking for the dd itself left the
/// line unwrapped.
fn nameIsAllowedInHost(node: *Instance, name_in: []const u8) !bool {
    const name = if (common.nameIn(name_in, &.{ "dd", "dt" })) "dl" else name_in;
    var current = try common.parent(node);
    while (current) |c| : (current = try common.parent(c)) {
        if (!try common.inSameEditingHost(node, c)) break;
        if (try common.isAllowedChild(.{ .name = name }, c)) return true;
    }
    return false;
}

/// Whether the nearest editable element with a formattable block name
/// around `node`, inside its editing host, is named `name`.
fn nearestFormatBlockIsNamed(node: *Instance, name: []const u8) !bool {
    var current = try common.parent(node);
    while (current) |c| : (current = try common.parent(c)) {
        if (!try common.isEditable(c)) return false;
        if (try common.isHtmlElementIn(c, &formattable_block_names)) return try common.localNameIs(c, name);
    }
    return false;
}

/// Whether formatBlock step 10.1 replaces `node` by its children: a
/// single-line container, except xmp and listing, which all three browsers
/// keep and wrap whole - `<xmp>[foo]</xmp>` + "p" gives `<p><xmp>foo</xmp>
/// </p>` (editing/run/formatblock.html: PPP for xmp, Chrome and Safari for
/// listing, wpt.fyi 2358bd4835), where the spec's single-line container
/// gives way to a p. Neither is an element Blink's formatBlock replaces
/// (format_block_command.cc IsElementForFormatBlock) nor one Gecko's does
/// (HTMLEditUtils::IsFormatTagForFormatBlockCommand). Golden rule 2, no
/// newer spec.
fn dissolvesForFormatBlock(node: *Instance) !bool {
    if (try common.isHtmlElementIn(node, &.{ "xmp", "listing" })) return false;
    return try common.isSingleLineContainer(node);
}

/// formatBlock's value, as Chrome and Safari compute it: the nearest
/// element with a formattable block name around the common ancestor of the
/// selection's VISIBLE range, unless it holds the editing host; "" when
/// there is none. The spec takes the block of the first visible leaf
/// instead, so a range across several blocks reports the first; Chrome 157
/// and Safari 27.2 report "" for `<p>[foo<p>bar]<p>baz` and "dl" for
/// `<dl><dt>[foo<dd>bar]</dl>` (editing/run/formatblock.html, wpt.fyi
/// 2358bd4835). The visible range is what Blink queries: `{<p><p> <p>foo
/// </p>}` reports "p" (the empty blocks hold no visible position) and a
/// range around a table cell's contents reports the block inside the cell.
/// A block holding other blocks is the value too: all three report "div"
/// for `<div><ol><li>[foo]</ol></div>` and `<div><table><tr><td>[foo]
/// </table></div>` (the data expects that after formatBlock, but the spec's
/// "" before it: Crane follows the browsers). The 4 rows that trades - the
/// value BEFORE on `<div>[foo<p>bar]</p></div>` and `<div><table><tr><td>
/// [foo]</table></div>`, both separators, FFF: all three report "div" - are
/// accepted for the 40 this gains (the user's ruling, 2026-11-19, lane
/// edit2; tools/wpt_loss_dispositions.txt kind user-ruling). Mechanism: Blink
/// ValueFormatBlock (editor_command.cc) over FirstEphemeralRangeOf(the
/// VisibleSelection) and FormatBlockCommand::ElementForFormatBlockCommand
/// (format_block_command.cc). Golden rule 2, no newer spec.
pub fn formatBlockValue(edit: *Edit) ![]const u8 {
    const value = try commonAncestorFormatBlockValue(edit);
    // A selection over several blocks that all carry one formattable name
    // answers that name (the user's ruling, 2026-11-21 ~2:25 PM ET, B5 (b):
    // "keep two blocks and answer the spec/Firefox value"): where the
    // common ancestor names no block ("") or only the dl around dd/dt
    // blocks, Firefox 160 and the data answer the blocks' shared name -
    // `<p>[foo<p>bar]` reports "p", and after formatBlock "dd" on it, "dd"
    // (editing/run/formatblock.html: the value-before rows FPF, the
    // value-after rows PPP, wpt.fyi 2358bd4835). Chrome 157 and Safari 27.2
    // reach the same "dd"/"div" after formatBlock only by making ONE block
    // (`<dd>foo<br>bar</dd>`), and answer "" before it; Crane keeps the
    // spec's two blocks (Firefox's), so it takes Firefox's value with them:
    // a "spec + one browser over a two-browser majority" ruling, like
    // selectAll (2026-11-11) and push-down (2026-11-19). Blocks of
    // different names keep the common ancestor's answer
    // (`<h1>[foo</h1><h2>bar]</h2>` is "" in Chrome, Safari and the data).
    if (value.len == 0 or std.mem.eql(u8, value, "dl")) {
        if (try sharedFormatBlockName(edit)) |shared| return shared;
    }
    return value;
}

/// The formattable block name every visible editable leaf of the
/// block-extended active range is in (its formatBlock owner, as the
/// indeterminacy reads it), or null when they differ, one has none, or
/// there is no leaf.
fn sharedFormatBlockName(edit: *Edit) !?[]const u8 {
    const range = (try blockExtendActiveRange(edit)) orelse return null;
    // The same answer as "every visible editable leaf's owner name, if one
    // and the same" with fewer visibility tests (each reads computed styles
    // up to the root): a leaf whose owner name equals the name already
    // shared cannot change the answer, visible or not, so only the leaves
    // before the first visible one and those that disagree are tested.
    // Leaves of one block share their owner, so its name is read once per
    // block (lane tpc: formatblock-value cost 1.76x the instructions with a
    // visibility test per leaf).
    var walk = try ContainedWalk.init(range);
    var shared: ?[]const u8 = null;
    var last_owner: ?*Instance = null;
    var last_name: []const u8 = "";
    while (try walk.next()) |leaf| {
        if (try common.hasChildren(leaf)) continue;
        if (!try common.isEditable(leaf)) continue;
        const owner = try formatBlockOwner(leaf);
        if (owner != last_owner) {
            last_owner = owner;
            last_name = if (try isFormatBlockCandidate(owner)) try formattableName(owner) else "";
        }
        const name = last_name;
        if (shared) |s| {
            if (name.len != 0 and std.mem.eql(u8, s, name)) continue;
            // It disagrees: it decides only if it is visible.
            if (try common.isVisible(leaf)) return null;
        } else {
            if (!try common.isVisible(leaf)) continue;
            if (name.len == 0) return null;
            shared = name;
        }
    }
    return shared;
}

/// Blink's ValueFormatBlock (see formatBlockValue's comment above).
fn commonAncestorFormatBlockValue(edit: *Edit) ![]const u8 {
    const start = (try edit.rangeStart()) orelse return "";
    const end = (try edit.rangeEnd()) orelse return "";
    const visible = visible_position.visibleRange(edit.scratchAllocator(), start, end) orelse return "";
    const host = (try common.editingHostOf(visible.start.node)) orelse return "";
    var current: ?*Instance = try commonAncestor(visible.start.node, visible.end.node);
    while (current) |c| : (current = try common.parent(c)) {
        if (!try common.isHtmlElementIn(c, &formattable_block_names)) continue;
        // The editing host or an element around it is not the value.
        if (common.isInclusiveDescendantOf(host, c)) return "";
        return formattableName(c);
    }
    return "";
}

/// The nearest inclusive ancestor of `a` that is also one of `b`.
fn commonAncestor(a: *Instance, b: *Instance) !?*Instance {
    var current: ?*Instance = a;
    while (current) |c| : (current = try common.parent(c)) {
        if (common.isInclusiveDescendantOf(b, c)) return c;
    }
    return null;
}

/// The dl a dt or dd belongs to, or null.
fn definitionListOf(node: *Instance) !?*Instance {
    if (!try common.isHtmlElementIn(node, &.{ "dt", "dd" })) return null;
    const p = (try common.parent(node)) orelse return null;
    return if (try common.isHtmlElementNamed(p, "dl")) p else null;
}

/// The formattable block name `node` carries (an interned constant).
fn formattableName(node: *Instance) ![]const u8 {
    for (formattable_block_names) |name| {
        if (try common.localNameIs(node, name)) return name;
    }
    return "";
}

/// formatBlock's indeterminacy.
pub fn formatBlockIndeterm(edit: *Edit) !bool {
    // Steps 1-2.
    const range = (try blockExtendActiveRange(edit)) orelse return false;
    // Step 3.
    var leaves: std.ArrayList(*Instance) = .empty;
    defer leaves.deinit(edit.allocator);
    try visibleEditableLeaves(edit, range, &leaves);
    // Step 4.
    if (leaves.items.len == 0) return false;
    // Steps 5-6. A dt and a dd of one dl count as that dl: Firefox 158, the
    // one browser with formatBlock indeterminacy (Chrome and Safari always
    // answer false), reports `<dl><dt>[foo<dd>bar]</dl>` as determinate
    // (editing/run/formatblock.html, PPP at wpt.fyi 5af3c135c9).
    var kind: ?[]const u8 = null;
    var kind_dl: ?*Instance = null;
    for (leaves.items) |leaf| {
        const node = try formatBlockOwner(leaf);
        const current: []const u8 = if (try isFormatBlockCandidate(node)) try formattableName(node) else "";
        const dl = try definitionListOf(node);
        if (kind != null and dl != null and dl == kind_dl) continue;
        kind_dl = dl;
        if (kind) |k| {
            if (!std.mem.eql(u8, k, current)) return true;
        } else kind = current;
    }
    // Step 7.
    return false;
}

test "formattable block names" {
    try std.testing.expect(common.nameIn("pre", &formattable_block_names));
    try std.testing.expect(common.nameIn("blockquote", &formattable_block_names));
    try std.testing.expect(!common.nameIn("li", &formattable_block_names));
    try std.testing.expect(!common.nameIn("ol", &formattable_block_names));
}

// ============================================================================
// A live copy of a range
// ============================================================================

/// A DOM Range made from a block-extended range, for the steps that mutate
/// the tree between block-extending and reading the range again (toggle
/// lists steps 5-8): a live range's boundary points follow the mutations,
/// as the spec's "new range" does. `release` frees it.
pub const LiveRange = struct {
    range: *Instance,
    generation: u64,

    pub fn init(edit: *Edit, from: Range) !LiveRange {
        const range = try interfaces.Document.call_createRange(edit.document);
        const live: LiveRange = .{ .range = range, .generation = runtime.SlabAllocator.generationOf(range) };
        errdefer live.release();
        try interfaces.Range.call_setStart(range, from.start.node, from.start.offset);
        try interfaces.Range.call_setEnd(range, from.end.node, from.end.offset);
        return live;
    }

    /// Its boundary points now.
    pub fn points(self: LiveRange) !Range {
        return .{
            .start = .{ .node = try interfaces.AbstractRange.get_startContainer(self.range), .offset = try interfaces.AbstractRange.get_startOffset(self.range) },
            .end = .{ .node = try interfaces.AbstractRange.get_endContainer(self.range), .offset = try interfaces.AbstractRange.get_endOffset(self.range) },
        };
    }

    pub fn release(self: LiveRange) void {
        self.range.releaseIfUnwrapped(self.generation);
    }
};
