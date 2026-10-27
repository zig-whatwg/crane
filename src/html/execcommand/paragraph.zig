//! The insertParagraph, insertLineBreak and insertHorizontalRule commands
//! (specs/w3c/execCommand.md), step by step. insertParagraph is the Enter
//! key and insertLineBreak Shift+Enter ("Additional requirements"); the key
//! path invokes them by name through the execcommand dispatch.
//!
//! The spec's outputs match all three browsers on most of
//! editing/run/insertparagraph.html, insertlinebreak.html and
//! inserthorizontalrule.html (wpt.fyi 5af3c135c9: Chrome 156, Firefox 158,
//! Safari 27 pass 238, 153 and 64 of the innerHTML subtests Crane failed
//! before these commands existed).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const common = @import("common.zig");
const block = @import("block.zig");
const delete = @import("delete.zig");
const split_parent = @import("split_parent.zig");
const wrap_mod = @import("wrap.zig");

const Edit = common.Edit;
const Point = common.Point;
const Instance = common.Instance;
const DOMString = runtime.DOMString;

fn isBr(node: *Instance) !bool {
    return try common.isHtmlElementNamed(node, "br");
}

/// Range.insertNode(node) on the active range.
fn insertNodeAtActiveRange(edit: *Edit, node: *Instance) !void {
    const range = (try edit.activeRange()) orelse return error.NoActiveRange;
    try interfaces.Range.call_insertNode(range, node);
    edit.modified = true;
}

/// The shared steps that keep insertNode off a Text node's edges: at its
/// start, collapse before it; at its end, after it (insertLineBreak steps
/// 5-6, insertHorizontalRule steps 8-9).
fn moveOffTextEdges(edit: *Edit) !void {
    var start = (try edit.rangeStart()) orelse return;
    if (common.isText(start.node) and start.offset == 0) {
        const p = (try common.parent(start.node)) orelse return;
        const before = try common.pointBefore(start.node, p);
        try edit.collapse(before.node, before.offset);
        start = before;
    }
    if (common.isText(start.node) and start.offset == try common.nodeLength(start.node)) {
        const p = (try common.parent(start.node)) orelse return;
        const after = try common.pointAfter(start.node, p);
        try edit.collapse(after.node, after.offset);
    }
}

/// Collapse the selection just after `node`.
fn collapseAfter(edit: *Edit, node: *Instance) !void {
    const p = (try common.parent(node)) orelse return;
    const after = try common.pointAfter(node, p);
    try edit.collapse(after.node, after.offset);
}

// ============================================================================
// insertLineBreak
// ============================================================================

/// The insertLineBreak command's action.
pub fn insertLineBreakAction(edit: *Edit) !bool {
    // Step 1.
    try delete.deleteTheSelection(edit, true, false, .forward);
    return insertLineBreakAfterDeletion(edit);
}

/// insertLineBreak's steps 2-11, which insertParagraph also takes where
/// it cannot make a paragraph.
fn insertLineBreakAfterDeletion(edit: *Edit) !bool {
    // Step 2.
    const start = (try edit.rangeStart()) orelse return true;
    if (!try common.isEditableOrEditingHost(start.node)) return true;
    // Step 3: an element that cannot take a br.
    if (common.isElement(start.node) and !try common.isAllowedChild(.{ .name = "br" }, start.node)) return true;
    // Step 4: a non-element whose parent cannot take a br.
    if (!common.isElement(start.node)) {
        const p = (try common.parent(start.node)) orelse return true;
        if (!try common.isAllowedChild(.{ .name = "br" }, p)) return true;
    }
    // A plaintext-only editing host whose white-space keeps newlines takes
    // a preformatted linefeed instead of the br (see insertLinefeed).
    if (try prefersLinefeed(edit, start)) return try insertLinefeed(edit, start);
    // Steps 5-6.
    try moveOffTextEdges(edit);
    // Steps 7-8.
    const br = try edit.createElement("br");
    try insertNodeAtActiveRange(edit, br);
    // Step 9.
    try collapseAfter(edit, br);
    // Step 10: a br that would collapse needs a second one to show the new
    // line. insertNode grows a collapsed range over the node it inserts, so
    // the caret goes back after the first br, as the reference
    // implementation does ("Compensate for nonstandard implementations of
    // insertNode").
    if (try common.isCollapsedLineBreak(br)) {
        const extra = try edit.createElement("br");
        try insertNodeAtActiveRange(edit, extra);
        try collapseAfter(edit, br);
    }
    // The browsers keep the white-space around the new line visible
    // (Gecko WhiteSpaceVisibilityKeeper): see keepEdgeSpacesVisible.
    try keepEdgeSpacesVisible(edit, try previousLeaf(br), try nextLeaf(br));
    // Step 11.
    return true;
}

/// Whether a line break at `point` is a preformatted linefeed: the point's
/// editing host is in the plaintext-only state (outside design mode) and
/// the white-space around the point keeps newlines (pre, pre-wrap,
/// pre-line, break-spaces). Gecko: HTMLEditUtils::
/// ShouldInsertLinefeedCharacter, "If in contenteditable=plaintext-only, we
/// should use linefeed when it's preformatted" (editor/libeditor/
/// HTMLEditUtils.cpp, gecko-dev 5836a062726f). Where the host is
/// contenteditable=true the spec's br stays (editing/run/insertlinebreak
/// .html).
fn prefersLinefeed(edit: *Edit, point: Point) !bool {
    var mode = try interfaces.Document.get_designMode(edit.document);
    defer mode.deinit(edit.document.ctx.allocator);
    if (std.mem.eql(u8, mode.asSlice(), "on")) return false;
    const host = (try common.editingHostOf(point.node)) orelse return false;
    if (!try common.isHtmlElement(host)) return false;
    var state = try interfaces.HTMLElement.get_contentEditable(host);
    defer state.deinit(host.ctx.allocator);
    if (!std.mem.eql(u8, state.asSlice(), "plaintext-only")) return false;
    return (try common.whiteSpaceAround(point.node)).preservesNewlines();
}

/// insertLineBreak's steps 5-11 for a preformatted linefeed: a "\n" into
/// the Text node at (or beside) `point`, or a new Text node there, the
/// caret after it, and - when that leaves an empty last line in its block -
/// a padding br after it so the line shows (`AB[]` -> `AB\n<br>`;
/// editing/plaintext-only/insertLineBreak.html ?white-space=pre, pre-line
/// and pre-wrap: Firefox 158 21/21 execCommand rows, Safari 27 16/21,
/// Chrome 156 15/21, wpt.fyi 5af3c135c9). Gecko inserts into an existing
/// Text node where there is one (HTMLEditor::InsertTextWithTransaction,
/// InsertTextTo::ExistingTextNodeIfAvailable) and pads with
/// InsertPaddingBRElementToMakeEmptyLineVisibleIfNeeded (editor/libeditor/
/// HTMLEditSubActionHandler.cpp, gecko-dev 5836a062726f).
fn insertLinefeed(edit: *Edit, point: Point) !bool {
    var text: *Instance = undefined;
    var after: u32 = 0;
    if (common.isText(point.node)) {
        text = point.node;
        try edit.insertData(text, point.offset, "\n");
        after = point.offset + 1;
    } else if (try textChild(try common.childBefore(point.node, point.offset))) |before| {
        text = before;
        const length = try common.nodeLength(before);
        try edit.insertData(text, length, "\n");
        after = length + 1;
    } else if (try textChild(try common.childAt(point.node, point.offset))) |at| {
        text = at;
        try edit.insertData(text, 0, "\n");
        after = 1;
    } else {
        text = try interfaces.Document.call_createTextNode(edit.document, DOMString.initInterned("\n"));
        try edit.insertBefore(point.node, text, try common.childAt(point.node, point.offset));
        after = 1;
    }
    edit.modified = true;
    try edit.collapse(text, after);
    // An empty last line: nothing follows the linefeed before its block
    // ends.
    if (after == try common.nodeLength(text) and (try nextLeaf(text)) == null) {
        const p = (try common.parent(text)) orelse return true;
        const br = try edit.createElement("br");
        try edit.insertBefore(p, br, try common.nextSibling(text));
    }
    return true;
}

fn textChild(node: ?*Instance) !?*Instance {
    const n = node orelse return null;
    return if (common.isText(n)) n else null;
}

// ============================================================================
// insertHorizontalRule
// ============================================================================

/// The insertHorizontalRule command's action.
pub fn insertHorizontalRuleAction(edit: *Edit) !bool {
    // Step 1.
    var start = (try edit.rangeStart()) orelse return true;
    var end = (try edit.rangeEnd()) orelse return true;
    // Step 2.
    while (start.offset == 0) {
        const p = (try common.parent(start.node)) orelse break;
        start = try common.pointBefore(start.node, p);
    }
    // Step 3.
    while (end.offset == try common.nodeLength(end.node)) {
        const p = (try common.parent(end.node)) orelse break;
        end = try common.pointAfter(end.node, p);
    }
    // Steps 4-5.
    try edit.collapse(start.node, start.offset);
    try edit.extend(end.node, end.offset);
    // Step 6.
    try delete.deleteTheSelection(edit, false, true, .forward);
    // Step 7.
    const after_delete = (try edit.rangeStart()) orelse return true;
    if (!try common.isEditableOrEditingHost(after_delete.node)) return true;
    // Steps 8-9.
    try moveOffTextEdges(edit);
    // Steps 10-11.
    const hr = try edit.createElement("hr");
    try insertNodeAtActiveRange(edit, hr);
    // Step 12.
    try block.fixDisallowedAncestors(edit, hr);
    // Step 13.
    try collapseAfter(edit, hr);
    // Step 14.
    return true;
}

// ============================================================================
// insertParagraph
// ============================================================================

/// The wrap context of insertParagraph step 11.7: never merge, a new
/// element named `tag`.
const NewContainerContext = struct {
    tag: []const u8,
    pub fn siblingCriteria(_: NewContainerContext, _: *Instance) anyerror!bool {
        return false;
    }
    pub fn newParent(self: NewContainerContext, edit: *Edit) anyerror!?*Instance {
        return try edit.createElement(self.tag);
    }
};

/// The last descendant of `node` in tree order, or null without children.
fn lastDescendant(node: *Instance) !?*Instance {
    var last = (try common.lastChild(node)) orelse return null;
    while (try common.lastChild(last)) |child| last = child;
    return last;
}

/// Copy every attribute of `from` onto `to` (insertParagraph step 23).
fn copyAttributes(edit: *Edit, from: *Instance, to: *Instance) !void {
    const allocator = from.ctx.allocator;
    const attributes = try interfaces.Element.get_attributes(from);
    const count = try interfaces.NamedNodeMap.get_length(attributes);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const attr = (try interfaces.NamedNodeMap.call_item(attributes, i)) orelse continue;
        var namespace = try interfaces.Attr.get_namespaceURI(attr);
        defer if (namespace) |*n| n.deinit(allocator);
        var name = try interfaces.Attr.get_name(attr);
        defer name.deinit(allocator);
        var value = try interfaces.Attr.get_value(attr);
        defer value.deinit(allocator);
        const ns: ?DOMString = if (namespace) |n| DOMString.initInterned(n.asSlice()) else null;
        try interfaces.Element.call_setAttributeNS(to, ns, DOMString.initInterned(name.asSlice()), .{ .domstring = DOMString.initInterned(value.asSlice()) });
    }
    edit.modified = true;
}

/// Remove the id attribute of every element descendant of `root` that is
/// not in `keep` (insertParagraph step 28).
fn unsetIdsExcept(edit: *Edit, root: *Instance, keep: []const *Instance) !void {
    var node = try common.firstChild(root);
    while (node) |n| : (node = try nextWithin(n, root)) {
        if (!common.isElement(n)) continue;
        if (std.mem.indexOfScalar(*Instance, keep, n) != null) continue;
        if (try common.hasAttribute(n, "id")) {
            try common.removeAttribute(n, "id");
            edit.modified = true;
        }
    }
}

/// The node after `node` in tree order inside `root`, or null.
fn nextWithin(node: *Instance, root: *Instance) !?*Instance {
    if (try common.firstChild(node)) |child| return child;
    var current: *Instance = node;
    while (current != root) {
        if (try common.nextSibling(current)) |sibling| return sibling;
        current = (try common.parent(current)) orelse return null;
    }
    return null;
}

/// The insertParagraph command's action.
pub fn insertParagraphAction(edit: *Edit) !bool {
    // Step 1.
    try delete.deleteTheSelection(edit, true, true, .forward);
    // Step 2.
    const range_start = (try edit.rangeStart()) orelse return true;
    if (!try common.isEditableOrEditingHost(range_start.node)) return true;
    // Step 3.
    var node = range_start.node;
    var offset = range_start.offset;
    // Step 4.
    if (common.isText(node) and offset != 0 and offset != try common.nodeLength(node)) {
        _ = try interfaces.Text.call_splitText(node, offset);
        edit.modified = true;
    }
    // Step 5.
    if (common.isText(node) and offset == try common.nodeLength(node)) {
        const p = (try common.parent(node)) orelse return true;
        const after = try common.pointAfter(node, p);
        node = after.node;
        offset = after.offset;
    }
    // Step 6.
    if (common.isText(node) or (try common.nodeType(node)) == interfaces.Node.get_COMMENT_NODE()) {
        const p = (try common.parent(node)) orelse return true;
        const before = try common.pointBefore(node, p);
        node = before.node;
        offset = before.offset;
    }
    // Step 7.
    try edit.collapse(node, offset);
    // No block to split: a line break instead (Chrome 156 and Firefox 158
    // pass `<h1 contenteditable=false><span contenteditable>ab[]cd</span>
    // </h1>` -> `ab<br>cd`, wpt.fyi 5af3c135c9; Gecko
    // AutoInsertParagraphHandler::ShouldInsertLineBreakInstead: no editable
    // block in the editing host, or an editing host that cannot hold a p).
    if (try shouldInsertLineBreakInstead(node)) return insertLineBreakAfterDeletion(edit);
    // Steps 8-9: the nearest single-line container in the editing host.
    var container = node;
    while (!try common.isSingleLineContainer(container)) {
        const p = (try common.parent(container)) orelse break;
        if (!try common.isEditable(p)) break;
        if (!try common.inSameEditingHost(p, node)) break;
        container = p;
    }
    // Step 10: a p or div inside a list item or dd/dt splits the item.
    if ((try common.isEditable(container)) and (try common.isSingleLineContainer(container)) and
        (try common.inSameEditingHost(container, node)) and try common.isHtmlElementIn(container, &.{ "p", "div" }))
    {
        var outer = container;
        while (!try common.isHtmlElementIn(outer, &.{ "dd", "dt", "li" })) {
            const p = (try common.parent(outer)) orelse break;
            if (!try common.isEditable(p)) break;
            outer = p;
        }
        if (try common.isHtmlElementIn(outer, &.{ "dd", "dt", "li" })) container = outer;
    }
    // Step 11: no container - wrap the line in the default single-line
    // container first.
    if (!(try common.isEditable(container)) or !(try common.inSameEditingHost(container, node)) or !try common.isSingleLineContainer(container)) {
        // Step 11.1.
        const tag = try block.defaultSingleLineContainerName(edit);
        // Step 11.2.
        const new_range = (try block.blockExtendActiveRange(edit)) orelse return true;
        // Steps 11.3-11.4.
        var node_list: std.ArrayList(*Instance) = .empty;
        defer node_list.deinit(edit.allocator);
        var walk = try block.ContainedWalk.init(new_range);
        while (try walk.next()) |candidate| {
            if (try block.isAllowedChildOfName(.{ .node = candidate }, "p")) {
                try node_list.append(edit.allocator, candidate);
                break;
            }
        }
        // Step 11.5: nothing to wrap - a new empty container at the caret.
        if (node_list.items.len == 0) {
            const start = (try edit.rangeStart()) orelse return true;
            // Step 11.5.1.
            if (!try common.isAllowedChild(.{ .name = tag }, start.node)) return true;
            // Steps 11.5.2-11.5.3.
            const new_container = try edit.createElement(tag);
            try insertNodeAtActiveRange(edit, new_container);
            // Step 11.5.4.
            try edit.appendChild(new_container, try edit.createElement("br"));
            // Step 11.5.5.
            try edit.collapse(new_container, 0);
            // Step 11.5.6.
            return true;
        }
        // Step 11.6.
        while (try common.nextSibling(node_list.items[node_list.items.len - 1])) |sibling| {
            if (!try block.isAllowedChildOfName(.{ .node = sibling }, "p")) break;
            try node_list.append(edit.allocator, sibling);
        }
        // Step 11.7.
        container = (try wrap_mod.wrap(edit, node_list.items, NewContainerContext{ .tag = tag })) orelse return true;
    }
    // Step 12: address, listing and pre take a br instead of a new block.
    if (try common.localNameIn(container, &.{ "address", "listing", "pre" })) {
        // Steps 12.1-12.2.
        var br = try edit.createElement("br");
        try insertNodeAtActiveRange(edit, br);
        // Step 12.3.
        try edit.collapse(node, offset + 1);
        // Step 12.4: a br at the very end shows no new line on its own.
        if ((try lastDescendant(container)) == br) {
            br = try edit.createElement("br");
            try insertNodeAtActiveRange(edit, br);
            // insertNode grows the collapsed range over the new br; keep the
            // caret where step 12.3 put it.
            try edit.collapse(node, offset + 1);
        }
        // Step 12.5.
        return true;
    }
    // Step 13: an empty list item or dd/dt breaks out of its list.
    if (try common.localNameIn(container, &.{ "li", "dt", "dd" })) {
        const count = try common.childCount(container);
        const empty = count == 0 or (count == 1 and try isBr((try common.firstChild(container)).?));
        if (empty) {
            // Step 13.1.
            try split_parent.splitParent(edit, &.{container});
            // Step 13.2.
            if (!try common.hasChildren(container)) try edit.appendChild(container, try edit.createElement("br"));
            // Step 13.3.
            if ((try common.isHtmlElementIn(container, &.{ "dd", "dt" })) and !try isAllowedChildOfAnAncestorInHost(container)) {
                container = try edit.setTagName(container, try block.defaultSingleLineContainerName(edit));
            }
            // Step 13.4.
            try block.fixDisallowedAncestors(edit, container);
            // Step 13.5.
            return true;
        }
    }
    // Step 14: the new line range, from the caret to container's end.
    const caret = (try edit.rangeStart()) orelse return true;
    const line_end: Point = .{ .node = container, .offset = try common.nodeLength(container) };
    // Steps 15-16, as the browsers do it: the spec moves the start out of
    // the inline elements it is at an edge of, so the new line keeps none
    // of them; all three browsers split those elements instead, and the
    // empty halves hold the line's style (`<p><b>foo[]</b></p>` ->
    // `<p><b>foo</b></p><p><b><br></b></p>`, and `<p><b>[]foo</b></p>` ->
    // `<p><b><br></b></p><p><b>foo</b></p>`: editing/run/insertparagraph.html,
    // Chrome 156, Firefox 158 and Safari 27 at wpt.fyi 5af3c135c9). Only a
    // link the caret is at an edge of is not continued: the split moves
    // before or after it (`<p><a href=foo>foo[]</a></p>` ->
    // `<p><a href="foo">foo</a></p><p><br></p>`, all three). Mechanism:
    // Gecko AutoInsertParagraphHandler::GetBetterPointToSplitParagraph and
    // SplitParagraphWithTransaction (editor/libeditor/
    // HTMLEditorInsertParagraphHandler.cpp, mozilla-firefox/firefox main
    // 2026-10-26), which split the inline ancestors deep and put the padding
    // <br> into the deepest one.
    var line_start = try betterSplitPoint(caret, container);
    // Past a link, Chrome 156 and Safari 27 carry none of the inline
    // elements around it either (`<p><b><a href=foo>foo&nbsp;[]</a></b></p>`
    // -> `...<p><br></p>`; Firefox 158 keeps the b): there the spec's steps
    // 15-16 apply.
    if (!line_start.eql(caret)) {
        // Step 15.
        while (line_start.offset == 0 and !try common.isProhibitedParagraphChild(line_start.node)) {
            const p = (try common.parent(line_start.node)) orelse break;
            line_start = try common.pointBefore(line_start.node, p);
        }
        // Step 16.
        while (line_start.offset == (try common.nodeLength(line_start.node)) and !try common.isProhibitedParagraphChild(line_start.node)) {
            const p = (try common.parent(line_start.node)) orelse break;
            line_start = try common.pointAfter(line_start.node, p);
        }
    }
    const line: block.Range = .{ .start = line_start, .end = line_end };
    // Step 17: the line range holds nothing, or a single br (its outermost
    // contained nodes).
    var end_of_line = true;
    {
        var walk = try block.ContainedWalk.init(line);
        var outermost: usize = 0;
        var only_br = true;
        while (try walk.next()) |contained| {
            outermost += 1;
            if (!try isBr(contained)) only_br = false;
            try walk.skipDescendants(contained);
        }
        end_of_line = outermost == 0 or (outermost == 1 and only_br);
    }
    // Steps 18-21.
    var name_buffer: [64]u8 = undefined;
    const container_name = (try common.localNameInto(container, &name_buffer)) orelse return true;
    const new_container_name: []const u8 = if (end_of_line and common.nameIn(container_name, &.{ "h1", "h2", "h3", "h4", "h5", "h6" }))
        try block.defaultSingleLineContainerName(edit)
    else if (end_of_line and std.mem.eql(u8, container_name, "dt"))
        "dd"
    else if (end_of_line and std.mem.eql(u8, container_name, "dd"))
        "dt"
    else
        container_name;
    // Step 22.
    var new_container = try edit.createElement(new_container_name);
    // Step 23.
    try copyAttributes(edit, container, new_container);
    // Step 24.
    if (try common.hasAttribute(new_container, "id")) try common.removeAttribute(new_container, "id");
    // Step 25.
    const container_parent = (try common.parent(container)) orelse return true;
    try edit.insertBefore(container_parent, new_container, try common.nextSibling(container));
    // Step 26: every node contained in the line range, descendants included.
    var contained_nodes: std.ArrayList(*Instance) = .empty;
    defer contained_nodes.deinit(edit.allocator);
    {
        var walk = try block.ContainedWalk.init(line);
        while (try walk.next()) |contained| try contained_nodes.append(edit.allocator, contained);
    }
    // Step 27: extractContents() on a range over the new line.
    const range = try interfaces.Document.call_createRange(edit.document);
    const range_generation = runtime.SlabAllocator.generationOf(range);
    defer range.releaseIfUnwrapped(range_generation);
    try interfaces.Range.call_setStart(range, line.start.node, line.start.offset);
    try interfaces.Range.call_setEnd(range, line.end.node, line.end.offset);
    const frag = try interfaces.Range.call_extractContents(range);
    const frag_generation = runtime.SlabAllocator.generationOf(frag);
    defer frag.releaseIfUnwrapped(frag_generation);
    edit.modified = true;
    // Step 28: ids of the elements the extraction cloned stay behind.
    try unsetIdsExcept(edit, frag, contained_nodes.items);
    // Step 29.
    try edit.appendChild(new_container, frag);
    // Step 30.
    while (try common.lastChild(container)) |last| {
        if (!try common.isProhibitedParagraphChild(last)) break;
        container = last;
    }
    // Step 31.
    while (try common.lastChild(new_container)) |last| {
        if (!try common.isProhibitedParagraphChild(last)) break;
        new_container = last;
    }
    // The split keeps the white-space at its edges visible (Gecko
    // WhiteSpaceVisibilityKeeper::PrepareToSplitBlockElement): `<div>a[] b
    // </div>` -> `<div>a</div><div>&nbsp;b</div>` and `<div>a []b</div>` ->
    // `<div>a&nbsp;</div><div>b</div>` in all three browsers
    // (insertparagraph.html, wpt.fyi 5af3c135c9).
    try keepEdgeSpacesVisible(edit, try lastLeaf(container), try firstLeaf(new_container));
    // Steps 32-33, after the browsers' split (see steps 15-16).
    try finishSplitSide(edit, container, .end);
    try finishSplitSide(edit, new_container, .start);
    // Step 34.
    try edit.collapse(new_container, 0);
    // Step 35.
    return true;
}

/// Whether insertParagraph inserts a line break instead of a paragraph at
/// `node`: no editable block element holds it in its editing host, or the
/// nearest one is the editing host and cannot hold a p (Gecko
/// AutoInsertParagraphHandler::ShouldInsertLineBreakInstead).
fn shouldInsertLineBreakInstead(node: *Instance) !bool {
    var current: ?*Instance = node;
    while (current) |c| : (current = try common.parent(c)) {
        const host = try common.isEditingHost(c);
        if (common.isBlockNode(c) and (host or try common.isEditable(c))) {
            if (!host) return false;
            return !try common.isAllowedChild(.{ .name = "p" }, c);
        }
        if (host) return true;
    }
    return true;
}

/// An a element with a non-empty href (Gecko HTMLEditUtils::IsHyperlinkElement).
fn isHyperlink(node: *Instance) !bool {
    if (!try common.isHtmlElementNamed(node, "a")) return false;
    var href = (try interfaces.Element.call_getAttribute(node, DOMString.initInterned("href"))) orelse return false;
    defer href.deinit(node.ctx.allocator);
    return href.asSlice().len > 0;
}

/// Whether something visible lies inside `ancestor` before `point` (a point
/// at an element offset, as steps 4-6 leave the caret).
fn hasVisibleBefore(point: Point, ancestor: *Instance) !bool {
    var node = point.node;
    var offset = point.offset;
    while (true) {
        var i = offset;
        while (i > 0) {
            i -= 1;
            if (try common.childAt(node, i)) |child| {
                if (try common.isVisible(child)) return true;
            }
        }
        if (node == ancestor) return false;
        const p = (try common.parent(node)) orelse return false;
        offset = try common.indexOf(node);
        node = p;
    }
}

/// Whether something visible lies inside `ancestor` after `point`.
fn hasVisibleAfter(point: Point, ancestor: *Instance) !bool {
    var node = point.node;
    var offset = point.offset;
    while (true) {
        var child = try common.childAt(node, offset);
        while (child) |c| : (child = try common.nextSibling(c)) {
            if (try common.isVisible(c)) return true;
        }
        if (node == ancestor) return false;
        const p = (try common.parent(node)) orelse return false;
        offset = 1 + try common.indexOf(node);
        node = p;
    }
}

/// The split point, moved out of the links `point` is at an edge of
/// (Gecko GetBetterPointToSplitParagraph): at the visible start of its
/// element, before the outermost link it starts; else at the visible end,
/// after the outermost link it ends.
fn betterSplitPoint(point: Point, block_element: *Instance) !Point {
    const closest = if (common.isElement(point.node)) point.node else ((try common.parent(point.node)) orelse return point);
    if (closest == block_element) return point;
    if (!try hasVisibleBefore(point, closest)) {
        var result = point;
        var current = closest;
        while (current != block_element) {
            if (try hasVisibleBefore(point, current)) break;
            const p = (try common.parent(current)) orelse break;
            if (try isHyperlink(current)) result = try common.pointBefore(current, p);
            current = p;
        }
        return result;
    }
    if (!try hasVisibleAfter(point, closest)) {
        var result = point;
        var current = closest;
        while (current != block_element) {
            if (try hasVisibleAfter(point, current)) break;
            const p = (try common.parent(current)) orelse break;
            if (try isHyperlink(current)) result = try common.pointAfter(current, p);
            current = p;
        }
        return result;
    }
    return point;
}

const Edge = enum { start, end };

/// Whether a split half holds nothing visible but, at most, one br as its
/// last leaf - the empty line Enter leaves behind.
fn isEmptyLine(container: *Instance) !bool {
    var brs: usize = 0;
    var last_leaf: ?*Instance = null;
    var last_br: ?*Instance = null;
    var node = try common.firstChild(container);
    while (node) |n| : (node = try nextWithin(n, container)) {
        if (try common.hasChildren(n)) continue;
        last_leaf = n;
        if (try isBr(n)) {
            brs += 1;
            last_br = n;
            continue;
        }
        if (try common.isVisible(n)) return false;
    }
    if (brs == 0) return true;
    return brs == 1 and last_leaf == last_br;
}

/// An inline element with nothing visible in it that the split left on
/// the edge of a half: on a line with content it goes; on an empty line a
/// span without attributes goes (it carries no style), the rest stay to
/// hold the line's style.
fn pruneEdgeInlines(edit: *Edit, container: *Instance, edge: Edge, empty_line: bool) !void {
    var chain: std.ArrayList(*Instance) = .empty;
    defer chain.deinit(edit.allocator);
    var current = container;
    while (true) {
        const child = (if (edge == .end) try common.lastChild(current) else try common.firstChild(current)) orelse break;
        if (!common.isElement(child) or !common.isInlineNode(child) or (try isBr(child)) or !try common.isEditable(child)) break;
        try chain.append(edit.allocator, child);
        current = child;
    }
    var i = chain.items.len;
    while (i > 0) {
        i -= 1;
        const element = chain.items[i];
        if (try common.isVisible(element)) continue;
        const plain_span = (try common.isHtmlElementNamed(element, "span")) and (try interfaces.NamedNodeMap.get_length(try interfaces.Element.get_attributes(element))) == 0;
        if (!empty_line or plain_span) try split_parent.removePreservingDescendants(edit, element);
    }
}

/// insertParagraph steps 32-33 for one half of the split, as the browsers
/// finish it (Gecko SplitParagraphWithTransaction): empty inline halves
/// stay only on an empty line, which gets its padding br in the deepest of
/// them (and loses a lone trailing br it already had).
fn finishSplitSide(edit: *Edit, container: *Instance, edge: Edge) !void {
    const empty_line = try isEmptyLine(container);
    if (empty_line) {
        if (try lastLeaf(container)) |leaf| {
            if (try isBr(leaf)) try edit.removeNode(leaf);
        }
    }
    try pruneEdgeInlines(edit, container, edge, empty_line);
    if (!empty_line) return;
    try edit.appendChild(try deepestTrailingInline(container), try edit.createElement("br"));
}

/// The deepest element ending `node` through last children that are
/// editable inline containers (not a br or an img): where a padding br
/// goes so the empty halves of a split keep their style.
fn deepestTrailingInline(node: *Instance) !*Instance {
    var target = node;
    while (try common.lastChild(target)) |last| {
        if (!common.isElement(last) or !common.isInlineNode(last)) break;
        if (try common.isHtmlElementIn(last, &.{ "br", "img", "hr", "input", "wbr" })) break;
        if (!try common.isEditable(last)) break;
        target = last;
    }
    return target;
}

fn lastLeaf(node: *Instance) !?*Instance {
    var leaf = (try common.lastChild(node)) orelse return null;
    while (try common.lastChild(leaf)) |child| leaf = child;
    return leaf;
}

fn firstLeaf(node: *Instance) !?*Instance {
    var leaf = (try common.firstChild(node)) orelse return null;
    while (try common.firstChild(leaf)) |child| leaf = child;
    return leaf;
}

/// The leaf before `node` in tree order, or null.
fn previousLeaf(node: *Instance) !?*Instance {
    var current = node;
    while (true) {
        if (try common.previousSibling(current)) |sibling| {
            var leaf = sibling;
            while (try common.lastChild(leaf)) |child| leaf = child;
            return leaf;
        }
        current = (try common.parent(current)) orelse return null;
        if (common.isBlockNode(current)) return null;
    }
}

/// The leaf after `node` in tree order, or null.
fn nextLeaf(node: *Instance) !?*Instance {
    var current = node;
    while (true) {
        if (try common.nextSibling(current)) |sibling| {
            var leaf = sibling;
            while (try common.firstChild(leaf)) |child| leaf = child;
            return leaf;
        }
        current = (try common.parent(current)) orelse return null;
        if (common.isBlockNode(current)) return null;
    }
}

/// Replace the ASCII space at `offset` of `text` by a no-break space (an
/// insert then a delete, so boundary points stay, as canonicalize
/// whitespace does).
fn spaceToNbsp(edit: *Edit, text: *Instance, offset: u32) !void {
    try edit.insertData(text, offset, "\u{a0}");
    try edit.deleteData(text, offset + 1, 1);
}

/// A collapsible space at the end of `before` or the start of `after`
/// becomes a no-break space, so the line edge does not swallow it.
fn keepEdgeSpacesVisible(edit: *Edit, before: ?*Instance, after: ?*Instance) !void {
    if (before) |text| {
        if (common.isText(text) and (try common.isEditable(text)) and !(try common.whiteSpaceAround(text)).preservesSpaces()) {
            const length = try common.nodeLength(text);
            if (length > 0) {
                var data = try common.textData(text);
                defer data.deinit(text.ctx.allocator);
                if (common.codeUnitAt(data.asSlice(), length - 1) == ' ') try spaceToNbsp(edit, text, length - 1);
            }
        }
    }
    if (after) |text| {
        if (common.isText(text) and (try common.isEditable(text)) and !(try common.whiteSpaceAround(text)).preservesSpaces()) {
            var data = try common.textData(text);
            defer data.deinit(text.ctx.allocator);
            if (common.codeUnitAt(data.asSlice(), 0) == ' ') try spaceToNbsp(edit, text, 0);
        }
    }
}

/// Whether `node` is an allowed child of any of its ancestors in the same
/// editing host (insertParagraph step 13.3).
fn isAllowedChildOfAnAncestorInHost(node: *Instance) !bool {
    var current = try common.parent(node);
    while (current) |c| : (current = try common.parent(c)) {
        if (!try common.inSameEditingHost(node, c)) continue;
        if (try common.isAllowedChild(.{ .node = node }, c)) return true;
    }
    return false;
}
