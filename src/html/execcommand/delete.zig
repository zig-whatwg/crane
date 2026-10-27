//! "Deleting the selection", the delete command and the forwardDelete
//! command (specs/w3c/execCommand.md), step by step.
//!
//! One deviation, ruled by the integrator (2026-10-23, golden rule 2 with
//! no newer spec involved): when the selection's start and end blocks are
//! siblings (step 34), the spec moves ALL of the end block's children into
//! the start block; Chrome and Safari move only the end block's FIRST LINE
//! and leave the rest as the next paragraph, and Firefox joins whole blocks
//! only when both have the same tag and white-space. On wpt.fyi (Chrome 156,
//! Firefox 158, Safari 27) editing/run/delete.html's whole-block cases such
//! as `<p>foo[</p><p>]bar<br>baz</p>` -> `<p>foobar<br>baz</p>` pass in
//! Firefox alone; Chrome and Safari produce `<p>foobar</p><p>baz</p>`.
//! Majority: the first line. Engines: Blink
//! DeleteSelectionCommand::MergeParagraphs (core/editing/commands/
//! delete_selection_command.cc) and WebKit
//! DeleteSelectionCommand::mergeParagraphs move the paragraph up to the
//! end of its first line; Gecko's AutoMoveOneLineHandler
//! (editor/libeditor/HTMLEditorDeleteHandler.cpp) moves one line too, its
//! TODO naming Chrome's behaviour as the target. The mechanism here is
//! Gecko's DOM-based one (a line ends at a br, a block boundary or a
//! preserved line feed) under the majority's rule.

const std = @import("std");
const runtime = @import("runtime");
const unicode_data = @import("url").idna.unicode_data_mod;
const interfaces = @import("interfaces");
const common = @import("common.zig");
const whitespace = @import("whitespace.zig");
const split_parent = @import("split_parent.zig");
const dom = @import("dom");
const overrides = @import("overrides.zig");
const block_formatting = @import("block.zig");
const lists = @import("lists.zig");
const indent = @import("indent.zig");

const Edit = common.Edit;
const Point = common.Point;
const Instance = common.Instance;

pub const Direction = enum { forward, backward };

const table_part_names = [_][]const u8{ "thead", "tbody", "tfoot", "tr", "th", "td" };
const list_item_names = [_][]const u8{ "li", "dt", "dd" };

fn isBr(node: *Instance) !bool {
    return try common.isHtmlElementNamed(node, "br");
}

/// DOM "contained": node's root is the range's, (node, 0) is after the
/// range's start and (node, length) is before its end.
fn isContained(node: *Instance, start: Point, end: Point) !bool {
    if (!try common.pointIsAfter(.{ .node = node, .offset = 0 }, start)) return false;
    return try common.pointIsBefore(.{ .node = node, .offset = try common.nodeLength(node) }, end);
}

/// The common ancestor of two nodes (the range's common ancestor container).
fn commonAncestor(a: *Instance, b: *Instance) !*Instance {
    var current: ?*Instance = a;
    while (current) |c| : (current = try common.parent(c)) {
        if (common.isInclusiveDescendantOf(b, c)) return c;
    }
    return a;
}

/// "delete the selection", given `block_merging` (default true),
/// `strip_wrappers` (default true) and `direction` (default forward).
pub fn deleteTheSelection(edit: *Edit, block_merging: bool, strip_wrappers: bool, direction: Direction) !void {
    // Step 1.
    if ((try edit.activeRange()) == null) return;
    // Steps 2-3.
    try whitespace.canonicalizeWhitespace(edit, (try edit.rangeStart()) orelse return, true);
    try whitespace.canonicalizeWhitespace(edit, (try edit.rangeEnd()) orelse return, true);
    // The range's start as given, for the browsers' caret placement (see
    // collapseForward).
    const original_start = (try edit.rangeStart()) orelse return;
    // Step 25.4's anchor without strip wrappers: the element holding the
    // range's start as given (its Text node may be deleted).
    const wrapper_anchor = if (common.isText(original_start.node)) (try common.parent(original_start.node)) orelse original_start.node else original_start.node;
    // Steps 4-5.
    var start = try common.lastEquivalentPoint(original_start);
    var end = try common.firstEquivalentPoint((try edit.rangeEnd()) orelse return);
    // Step 6: equivalent but not identical points: nothing to delete.
    if (!try common.pointIsAfter(end, start)) {
        if (direction == .forward) try edit.collapseToStart() else try edit.collapseToEnd();
        return;
    }
    // Step 7.
    if (common.isText(start.node) and start.offset == 0) {
        if (try common.parent(start.node)) |p| {
            start = try common.pointBefore(start.node, p);
        }
    }
    // Step 8.
    if (common.isText(end.node) and end.offset == try common.nodeLength(end.node)) {
        if (try common.parent(end.node)) |p| {
            end = try common.pointAfter(end.node, p);
        }
    }
    // Steps 9-10.
    try edit.collapse(start.node, start.offset);
    try edit.extend(end.node, end.offset);
    // Steps 12-14: the start block.
    var start_block: ?*Instance = start.node;
    while (start_block) |block| {
        const p = (try common.parent(block)) orelse break;
        if (!(try common.inSameEditingHost(block, p)) or !common.isInlineNode(block)) break;
        start_block = p;
    }
    if (start_block) |block| {
        if (!(common.isBlockNode(block) or try common.isEditingHost(block)) or
            !(try common.isAllowedChild(.{ .name = "span" }, block)) or
            try common.isHtmlElementIn(block, &.{ "td", "th" }))
        {
            start_block = null;
        }
    }
    // Steps 15-17: the end block.
    var end_block: ?*Instance = end.node;
    while (end_block) |block| {
        const p = (try common.parent(block)) orelse break;
        if (!(try common.inSameEditingHost(block, p)) or !common.isInlineNode(block)) break;
        end_block = p;
    }
    if (end_block) |block| {
        if (!(common.isBlockNode(block) or try common.isEditingHost(block)) or
            !(try common.isAllowedChild(.{ .name = "span" }, block)) or
            try common.isHtmlElementIn(block, &.{ "td", "th" }))
        {
            end_block = null;
        }
    }
    // Step 32's browser rule, decided on the range before anything goes.
    const keeps_child_block = if (!edit.range_from_caret and start_block != null and end_block != null and common.isAncestorOf(start_block.?, end_block.?))
        try rangeKeepsChildBlock(start, end_block.?)
    else
        false;
    // Steps 18-19, with the values in effect where the deletion STARTS (the
    // range's start as given, before steps 4-5 moved it): golden rule 2,
    // the browsers' majority - Blink saves its typing style from the start
    // of the selection it deletes (DeleteSelectionCommand::
    // SaveTypingStyleState, chromium f31874d8d6d0), Chrome 156 and Safari
    // 27 pass multitest.html ?9001-last's class-B rows, Firefox 158 follows
    // the spec's first formattable node (wpt.fyi c645564b0e). See
    // overrides.recordCurrentStatesAndValues.
    const recorded = try overrides.recordCurrentStatesAndValues(edit, original_start.node);
    // Step 21: one editable Text node.
    if (start.node == end.node and common.isText(start.node) and try common.isEditable(start.node)) {
        try edit.deleteData(start.node, start.offset, end.offset - start.offset);
        try whitespace.canonicalizeWhitespace(edit, start, false);
        if (direction == .forward) try collapseForward(edit, original_start) else try edit.collapseToEnd();
        try overrides.restoreStatesAndValues(edit, recorded);
        return;
    }
    // Step 22.
    if (common.isText(start.node) and try common.isEditable(start.node)) {
        try edit.deleteData(start.node, start.offset, (try common.nodeLength(start.node)) - start.offset);
    }
    // Steps 23-24: the nodes contained in the active range, outermost first.
    var node_list: std.ArrayList(*Instance) = .empty;
    defer node_list.deinit(edit.allocator);
    {
        const range_start = (try edit.rangeStart()) orelse return;
        const range_end = (try edit.rangeEnd()) orelse return;
        const root = try commonAncestor(range_start.node, range_end.node);
        var current = try common.firstChild(root);
        while (current) |node| {
            if (!common.isInclusiveDescendantOf(node, root)) break;
            if (try isContained(node, range_start, range_end)) {
                if ((try common.isEditable(node)) and !try common.isHtmlElementIn(node, &table_part_names)) {
                    try node_list.append(edit.allocator, node);
                    // Its descendants are contained too and skipped: the last
                    // member is their ancestor.
                    current = try common.nextSkippingChildren(node);
                    continue;
                }
            }
            current = try common.nextInTreeOrder(node);
        }
    }
    // Step 25. Steps 25.3 and 25.4 run in the browsers' order: the emptied
    // inline wrappers are stripped FIRST, then the br pads whatever is left
    // (golden rule 2, no newer spec). The spec pads the wrapper and then
    // cannot strip it (its length is 1): `<p><b>[foo]</b>` would become
    // `<p><b><br></b></p>`; Chrome 156, Firefox 158 and Safari 27 all give
    // `<p><br></p>`, and the same for `<p><b><i>[foo]</i></b>` and
    // `<span>[abc]</span>` -> `<br>` (editing/run/delete.html and
    // forwarddelete.html at wpt.fyi c645564b0e).
    for (node_list.items) |node| {
        // Step 25.1.
        var p = (try common.parent(node)) orelse continue;
        // Step 25.2.
        try edit.removeNode(node);
        // Step 25.4: strip the emptied inline wrappers. Without strip
        // wrappers (insertText), the wrappers kept are those around the
        // range's start as given, not the start steps 4 and 7 normalized
        // into the next inline: `foo<b>[bar]</b>baz` keeps the <b>,
        // `abc[<b><i><img>def]</i></b>ghi` loses both (Chrome 155 and
        // Firefox 158 type `abcdefghi`; editing/run/inserttext.html at
        // wpt.fyi df642c4142; golden rule 2, no newer spec).
        const kept_start = if (strip_wrappers) start.node else wrapper_anchor;
        if (strip_wrappers or !common.isInclusiveDescendantOf(kept_start, p)) {
            while ((try common.isEditable(p)) and common.isInlineNode(p) and (try common.nodeLength(p)) == 0) {
                const grandparent = (try common.parent(p)) orelse break;
                try edit.removeNode(p);
                p = grandparent;
            }
        }
        // Step 25.3: a block emptied by the removal gets a br.
        if (try common.blockNodeOf(p)) |block| {
            if (!(try hasVisibleChild(block)) and try common.isEditableOrEditingHost(p)) {
                const br = try edit.createElement("br");
                try edit.appendChild(p, br);
            }
        }
    }
    // Step 26.
    if (common.isText(end.node) and try common.isEditable(end.node)) {
        try edit.deleteData(end.node, 0, end.offset);
    }
    // Steps 27-28.
    try whitespace.canonicalizeWhitespace(edit, (try edit.rangeStart()) orelse return, false);
    try whitespace.canonicalizeWhitespace(edit, (try edit.rangeEnd()) orelse return, false);
    // Step 30: no block merge.
    if (!block_merging or start_block == null or end_block == null or
        !(try common.inSameEditingHost(start_block.?, end_block.?)) or start_block.? == end_block.?)
    {
        if (direction == .forward) try collapseForward(edit, original_start) else try edit.collapseToEnd();
        try overrides.restoreStatesAndValues(edit, recorded);
        return;
    }
    const sb = start_block.?;
    var eb = end_block.?;
    // Step 31: a lone collapsed block prop in the start block goes.
    if ((try common.childCount(sb)) == 1) {
        const only = (try common.firstChild(sb)).?;
        if (try common.isCollapsedBlockProp(only)) try edit.removeNode(only);
    }
    var values: overrides.Values = .{};
    if (common.isAncestorOf(sb, eb)) {
        // Step 32: the end block is inside the start block.
        // Steps 32.1-32.2.
        var reference = eb;
        while ((try common.parent(reference)) != sb) reference = (try common.parent(reference)) orelse break;
        // Step 32.3.
        try edit.collapse(sb, try common.indexOf(reference));
        // Step 32.4: an empty end block is removed with its empty wrappers.
        if (!try common.hasChildren(eb)) {
            // Step 32.4.1.
            while (try common.isEditable(eb)) {
                const p = (try common.parent(eb)) orelse break;
                if (p == sb or (try common.childCount(p)) != 1) break;
                try edit.removeNode(eb);
                eb = p;
            }
            // Step 32.4.2.
            if ((try common.isEditable(eb)) and !common.isInlineNode(eb)) {
                const previous = try common.previousSibling(eb);
                const next = try common.nextSibling(eb);
                if (previous != null and next != null and common.isInlineNode(previous.?) and common.isInlineNode(next.?)) {
                    const br = try edit.createElement("br");
                    try edit.insertBefore((try common.parent(eb)).?, br, next);
                }
            }
            // Step 32.4.3.
            if (try common.isEditable(eb)) try edit.removeNode(eb);
            // Steps 32.4.4-32.4.5.
            try overrides.restoreStatesAndValues(edit, recorded);
            return;
        }
        // Step 32.5.
        if (!common.isInlineNode((try common.firstChild(eb)).?)) {
            try overrides.restoreStatesAndValues(edit, recorded);
            return;
        }
        // A range from the start of a line into a child block deletes the
        // lines before the block and leaves the block whole, the caret at
        // its start (golden rule 2, no newer spec: the spec's steps 32.6-
        // 32.11 unwrap its first line) - unless the block would be left
        // with nothing visible. See rangeKeepsChildBlock.
        if (keeps_child_block and try hasVisibleChild(eb)) {
            try edit.collapse(eb, 0);
            try overrides.restoreStatesAndValues(edit, recorded);
            return;
        }
        // Steps 32.6-32.8: the end block's first line - under the
        // browsers' line rule (see extractFirstLine), which also ends it at
        // a preserved line feed and inside an inline.
        var line: Line = .{};
        defer line.deinit(edit.allocator);
        try extractFirstLine(edit, (try common.firstChild(eb)).?, &line, .move);
        if (line.nodes.items.len == 0) {
            // Nothing on the line to move (a line feed, or an inline that
            // held only its br): an end block left empty goes, with its
            // emptied ancestors.
            while (!try common.hasChildren(eb) and eb != sb and try common.isEditable(eb)) {
                const p = (try common.parent(eb)) orelse break;
                try edit.removeNode(eb);
                eb = p;
            }
        } else {
            const children = line.nodes.items;
            try line.recordWhiteSpace(edit, sb);
            // Step 32.9.
            values = try overrides.recordTheValues(edit, children);
            // Step 32.10.
            while ((try common.parent(children[0])) != sb) {
                try split_parent.splitParent(edit, children);
            }
            // Step 32.11.
            if (try common.previousSibling(children[0])) |previous| {
                if ((try common.isEditable(previous)) and try isBr(previous)) try edit.removeNode(previous);
            }
            try line.preserveWhiteSpace(edit);
        }
    } else if (common.isDescendantOf(sb, eb)) {
        // Step 33: the start block is inside the end block - pull in what
        // follows it up to a br or block node.
        // Step 33.1.
        try edit.collapse(sb, try common.nodeLength(sb));
        // Steps 33.2-33.3.
        var reference = sb;
        while ((try common.parent(reference)) != eb) reference = (try common.parent(reference)) orelse break;
        // Step 33.4.
        if (try common.nextSibling(reference)) |next| {
            if (common.isInlineNode(next)) {
                if (try common.lastChild(sb)) |last| {
                    if (try isBr(last)) try edit.removeNode(last);
                }
            }
        }
        // Steps 33.5-33.7: the line after reference, under the browsers'
        // line rule (see extractFirstLine).
        var line: Line = .{};
        defer line.deinit(edit.allocator);
        if (try common.nextSibling(reference)) |next| {
            try extractFirstLine(edit, next, &line, .move);
        }
        try line.recordWhiteSpace(edit, sb);
        // Step 33.8.
        values = try overrides.recordTheValues(edit, line.nodes.items);
        // Step 33.9.
        for (line.nodes.items) |node| {
            try edit.movePreservingRanges(node, sb, try common.childCount(sb));
        }
        try line.preserveWhiteSpace(edit);
    } else {
        // Step 34: sibling blocks - the end block's first line joins the
        // start block (the browsers' rule, see the module comment).
        // Step 34.1.
        try edit.collapse(sb, try common.nodeLength(sb));
        // Step 34.2.
        if (try common.firstChild(eb)) |first| {
            if (common.isInlineNode(first)) {
                if (try common.lastChild(sb)) |last| {
                    if (try isBr(last)) try edit.removeNode(last);
                }
            }
        }
        // Step 34.3.
        values = try overrides.recordTheValues(edit, &.{eb});
        // Step 34.4 (first line): move the children up to the line's end;
        // the br or line feed that ended it is deleted.
        var line: Line = .{};
        defer line.deinit(edit.allocator);
        if (try common.firstChild(eb)) |first| try extractFirstLine(edit, first, &line, .delete);
        try line.recordWhiteSpace(edit, sb);
        for (line.nodes.items) |node| {
            try edit.movePreservingRanges(node, sb, try common.childCount(sb));
        }
        try line.preserveWhiteSpace(edit);
        // Step 34.5.
        while (!try common.hasChildren(eb)) {
            const p = (try common.parent(eb)) orelse break;
            try edit.removeNode(eb);
            eb = p;
        }
    }
    // Steps 36-37: adjacent lists left by the deletion merge.
    var ancestor = sb;
    while (try hasMergeableListAncestor(ancestor)) {
        // Step 37.1.
        while (!try isListFollowedByList(ancestor)) ancestor = (try common.parent(ancestor)) orelse break;
        // Step 37.2.
        const next = (try common.nextSibling(ancestor)) orelse break;
        while (try common.firstChild(next)) |child| {
            try edit.movePreservingRanges(child, ancestor, try common.childCount(ancestor));
        }
        // Step 37.3.
        try edit.removeNode(next);
    }
    // Step 38.
    try overrides.restoreTheValues(edit, values);
    // Step 39.
    if (!try common.hasChildren(sb)) {
        const br = try edit.createElement("br");
        try edit.appendChild(sb, br);
    }
    // Step 40.
    try edit.removeExtraneousLineBreaksAtTheEndOf(sb);
    // Step 41.
    try overrides.restoreStatesAndValues(edit, recorded);
}

/// Steps 21.3 and 30.1: collapse the selection to its start - at the range's
/// ORIGINAL start when it is still in the tree and an equivalent point of
/// the normalized start (golden rule 2, no newer spec). Steps 4
/// and 7 move a start at a text node's end to the first equivalent point
/// inside the following inline (`<div>abc[<b><i>de]f</i></b>ghi</div>` ->
/// the caret at (i, 0)), so text typed next lands in <b><i>. Chrome 156 and
/// Safari 27 keep the caret in "abc" and type `abcde<b><i>f</i></b>ghi`;
/// Firefox 158 types `abc<b><i>def</i></b>ghi` as the spec does. wpt.fyi
/// c645564b0e, editing/run/multitest.html?9001-last, delete and
/// forwarddelete then inserttext d,e on `<div>abc[<b><i>de]f</i></b>ghi</div>`,
/// `<div>abc{<b><i>de]f</i></b>ghi</div>` and the <img> form: Chrome and
/// Safari pass all six, Firefox fails five. Majority: the original start.
fn collapseForward(edit: *Edit, original_start: Point) !void {
    if ((interfaces.Node.get_isConnected(original_start.node) catch false) and
        original_start.offset <= try common.nodeLength(original_start.node))
    {
        if (try edit.rangeStart()) |current| {
            if (!current.eql(original_start) and (try common.lastEquivalentPoint(original_start)).eql(try common.lastEquivalentPoint(current))) {
                return edit.collapse(original_start.node, original_start.offset);
            }
        }
    }
    try edit.collapseToStart();
}

/// forwardDelete at an empty line right before a block: the browsers delete
/// that line alone - its br, or its preserved line feed, with an inline
/// wrapper it empties - and put the caret at the block's start, where the
/// spec's step 5 or 7 range reaches into the block and joins it (golden
/// rule 2, no newer spec): `abc<br>{}<br><div>def</div>` -> `abc<br><div>[]def</div>`,
/// `<b>{}<br></b><div>def</div>` -> `<div>[]def</div>`. Gecko:
/// AutoBlockElementsJoiner's DeletePrecedingBRElementOfBlock and
/// DeletePrecedingPreformattedLineBreak (mozilla-firefox/firefox
/// 6cb22fec8a1e); editing/other/delete-without-unwrapping-first-line-of-
/// child-block.html ?method=forwardDeleteCommand, Chrome 155 and Firefox
/// 158 25/25 (wpt.fyi df642c4142). Whether it did.
fn deleteEmptyLineBeforeBlock(edit: *Edit, point: Point) !bool {
    if (common.isText(point.node)) {
        const length = try common.nodeLength(point.node);
        if (point.offset + 1 != length or !try isPreservedLineFeedBefore(point.node, length)) return false;
        const block = (try blockRightAfter(point.node)) orelse return false;
        if ((try lineStartKind(point)) == .none) return false;
        try edit.deleteData(point.node, point.offset, 1);
        if ((try common.nodeLength(point.node)) == 0) try removeWithEmptiedWrappers(edit, point.node);
        try edit.collapse(block, 0);
        return true;
    }
    const br = (try common.childAt(point.node, point.offset)) orelse return false;
    if (!try isBr(br) or !try common.isEditable(br)) return false;
    const block = (try blockRightAfter(br)) orelse return false;
    if ((try lineStartKind(point)) == .none) return false;
    try removeWithEmptiedWrappers(edit, br);
    try edit.collapse(block, 0);
    return true;
}

/// The block that follows `node` directly - its next sibling, or its inline
/// ancestors' - or null when something else comes first.
fn blockRightAfter(node: *Instance) !?*Instance {
    var current = node;
    while (true) {
        if (try common.nextSibling(current)) |next| {
            // A nested list is not this rule's: Gecko joins it through its
            // list handling, and so does the spec (editing/run/
            // forwarddelete.html `<li>{}<br><ol><li>bar</ol></li>`).
            if (try common.isHtmlElementIn(next, &.{ "ol", "ul" })) return null;
            return if (common.isBlockNode(next) and try common.isEditable(next)) next else null;
        }
        const p = (try common.parent(current)) orelse return null;
        if (!common.isInlineNode(p) or !try common.isEditable(p)) return null;
        current = p;
    }
}

/// Remove `node`, then the editable inline ancestors it leaves empty.
fn removeWithEmptiedWrappers(edit: *Edit, node: *Instance) !void {
    var p = (try common.parent(node)) orelse return edit.removeNode(node);
    try edit.removeNode(node);
    while ((try common.isEditable(p)) and common.isInlineNode(p) and (try common.nodeLength(p)) == 0) {
        const grandparent = (try common.parent(p)) orelse break;
        try edit.removeNode(p);
        p = grandparent;
    }
}

const EmptyLineBreak = union(enum) {
    br: *Instance,
    /// A Text node whose last character is the line feed.
    line_feed: *Instance,
};

/// The line break that ends what `node` (the node before a block) ends
/// with - its last br, or a preserved line feed at the end of its last
/// text, looking into inline elements - when that line break starts a line
/// itself (it makes an empty line).
fn emptyLineBreakBefore(node: *Instance) !?EmptyLineBreak {
    var current = node;
    while (common.isElement(current) and !(try isBr(current)) and common.isInlineNode(current)) {
        current = (try common.lastChild(current)) orelse return null;
    }
    if (try isBr(current)) {
        const p = (try common.parent(current)) orelse return null;
        if ((try lineStartKind(try common.pointBefore(current, p))) == .none) return null;
        return .{ .br = current };
    }
    if (common.isText(current)) {
        const length = try common.nodeLength(current);
        if (length == 0 or !try isPreservedLineFeedBefore(current, length)) return null;
        if ((try lineStartKind(.{ .node = current, .offset = length - 1 })) == .none) return null;
        return .{ .line_feed = current };
    }
    return null;
}

/// Whether deleting from `start` into `child_block`, a block inside the
/// start block, leaves the child block whole instead of unwrapping its
/// first line: Gecko's AutoBlockElementsJoiner mode
/// DeletePrecedingLinesAndContentInRange ("If the range starts immediately
/// after a line end and ends in a child right block, we should not unwrap
/// the right block"; editor/libeditor/HTMLEditorDeleteHandler.cpp,
/// mozilla-firefox/firefox 6cb22fec8a1e, the ComputeRangesToDelete
/// prologue of AutoBlockElementsJoiner::Prepare). The range must start at a
/// line start - after a br, a preserved line feed, a block or at its
/// block's start - and either select something visible before the child
/// block or start right after a line break that itself starts a line (an
/// empty line). editing/other/delete-without-unwrapping-first-line-of-
/// child-block.html at wpt.fyi df642c4142: the deleteCommand variants pass
/// in Chrome 155 and Firefox 158 (25/25 each); Safari 27 passes the
/// preformatted ones (25/25) and 9/25 of the br ones. Golden rule 2, no
/// newer spec (the spec's steps 32.6-32.11 unwrap the first line):
/// `abc<br>{<br><div>]def<br>ghi</div>` -> `abc<br><div>def<br>ghi</div>`,
/// while `foo<br><p>[]bar</p>` still joins.
fn rangeKeepsChildBlock(start: Point, child_block: *Instance) !bool {
    return switch (try lineStartKind(start)) {
        .none => false,
        .block => try selectsVisibleBefore(start, child_block),
        .line_break => |starts_line| starts_line or try selectsVisibleBefore(start, child_block),
    };
}

const LineStart = union(enum) {
    none,
    /// At the start of a block, or right after one.
    block,
    /// Right after a br or a preserved line feed; whether that line break
    /// itself starts a line (it makes an empty line).
    line_break: bool,
};

/// What, if anything, makes `point` a line start, looking back past
/// nothing visible.
fn lineStartKind(point: Point) anyerror!LineStart {
    var node = point.node;
    var offset = point.offset;
    if (common.isText(node)) {
        if (offset > 0) {
            if (!try isPreservedLineFeedBefore(node, offset)) return .none;
            return .{ .line_break = (try lineStartKind(.{ .node = node, .offset = offset - 1 })) != .none };
        }
        offset = try common.indexOf(node);
        node = (try common.parent(node)) orelse return .block;
    }
    while (true) {
        if (offset == 0) {
            if (common.isBlockNode(node) or try common.isEditingHost(node)) return .block;
            const p = (try common.parent(node)) orelse return .block;
            offset = try common.indexOf(node);
            node = p;
            continue;
        }
        const before = (try common.childAt(node, offset - 1)) orelse return .none;
        if (common.isBlockNode(before)) return .block;
        if (try isBr(before)) {
            return .{ .line_break = (try lineStartKind(try common.pointBefore(before, node))) != .none };
        }
        if (common.isText(before)) {
            const length = try common.nodeLength(before);
            if (length == 0) {
                offset -= 1;
                continue;
            }
            if (!try isPreservedLineFeedBefore(before, length)) return .none;
            return .{ .line_break = (try lineStartKind(.{ .node = before, .offset = length - 1 })) != .none };
        }
        // An inline element: what ends it.
        if (common.isElement(before) and try common.hasChildren(before)) {
            node = before;
            offset = try common.childCount(before);
            continue;
        }
        return .none;
    }
}

/// Whether the code unit before `offset` in `text` is a line feed its
/// white-space preserves.
fn isPreservedLineFeedBefore(text: *Instance, offset: u32) !bool {
    if (!(try common.whiteSpaceAround(text)).preservesNewlines()) return false;
    var data = try common.textData(text);
    defer data.deinit(text.ctx.allocator);
    return common.codeUnitAt(data.asSlice(), offset - 1) == '\n';
}

/// Whether something visible lies between `start` and `block` in tree
/// order: a br, an img, visible text, a block other than `block`'s
/// ancestors.
fn selectsVisibleBefore(start: Point, block: *Instance) !bool {
    var current: ?*Instance = undefined;
    if (common.isText(start.node)) {
        var data = try common.textData(start.node);
        defer data.deinit(start.node.ctx.allocator);
        const preserves = (try common.whiteSpaceAround(start.node)).preservesSpaces();
        const from = common.byteOffsetOfUnits(data.asSlice(), start.offset);
        for (data.asSlice()[from..]) |byte| switch (byte) {
            ' ', '\t', '\n', '\r', '\x0c' => if (preserves) return true,
            else => return true,
        };
        current = try common.nextSkippingChildren(start.node);
    } else {
        current = (try common.childAt(start.node, start.offset)) orelse try common.nextSkippingChildren(start.node);
    }
    while (current) |node| {
        if (node == block) return false;
        if (common.isAncestorOf(node, block)) {
            current = try common.firstChild(node);
            continue;
        }
        if ((try isBr(node)) or try common.isVisible(node)) return true;
        current = try common.nextSkippingChildren(node);
    }
    return false;
}

/// One line of a block that a join moves (steps 32-34), with what it needs
/// to keep its white-space where it lands.
const Line = struct {
    /// The line's top-level nodes, consecutive children of one container.
    nodes: std.ArrayList(*Instance) = .empty,
    /// Each node's computed white-space before the move (null: none).
    styles: std.ArrayList(?common.WhiteSpaceStyles) = .empty,
    /// False when the <pre> exception below applies to this join.
    preserve: bool = false,

    fn deinit(self: *Line, allocator: std.mem.Allocator) void {
        self.nodes.deinit(allocator);
        self.styles.deinit(allocator);
    }

    /// Record the nodes' white-space before they move into `destination`
    /// (Gecko: HTMLEditor::AutoMoveOneLineHandler::Prepare, then
    /// MoveNodeOrChildrenWithTransaction reads the source's computed
    /// white-space before moving it).
    fn recordWhiteSpace(self: *Line, edit: *Edit, destination: *Instance) !void {
        self.styles.clearRetainingCapacity();
        if (self.nodes.items.len == 0) return;
        self.preserve = try considerPreservingWhiteSpace(self.nodes.items[0], destination);
        for (self.nodes.items) |node| {
            try self.styles.append(edit.allocator, if (self.preserve) try common.whiteSpaceStylesAround(node) else null);
        }
    }

    /// After the move: a node whose white-space differs from its new
    /// parent's keeps its own (Gecko, MoveNodeOrChildrenWithTransaction):
    /// an HTML element gets `white-space` in its style attribute; anything
    /// else - a Text node - is wrapped in a new <span style="white-space: v">,
    /// one per node, where the parent may hold a span and the span the node.
    /// Gecko's output is the first accepted entry of every
    /// editing/other/join-different-white-space-style-*.html expectation;
    /// Chrome 155, Firefox 158 and Safari 27 pass those files in full
    /// (wpt.fyi df642c4142).
    fn preserveWhiteSpace(self: *Line, edit: *Edit) !void {
        if (!self.preserve) return;
        for (self.nodes.items, self.styles.items) |node, recorded| {
            const source = recorded orelse continue;
            if (try isBr(node)) continue;
            const value = source.shorthandValue() orelse continue;
            const new_parent = (try common.parent(node)) orelse continue;
            if (!common.isElement(new_parent)) continue;
            const destination = common.whiteSpaceStylesOf(new_parent) orelse continue;
            if (destination.collapse == .preserve_spaces or destination.eql(source)) continue;
            if (common.isElement(node)) {
                if (try common.setInlineStyleProperty(node, "white-space", value)) {
                    edit.modified = true;
                    continue;
                }
            }
            if (!try common.isAllowedChild(.{ .name = "span" }, new_parent)) continue;
            const span = try edit.createElement("span");
            if (!try common.isAllowedChild(.{ .node = node }, span)) continue;
            var buffer: [64]u8 = undefined;
            try common.setAttribute(span, "style", try std.fmt.bufPrint(&buffer, "white-space: {s}", .{value}));
            try edit.insertBefore(new_parent, span, node);
            try edit.movePreservingRanges(node, span, 0);
        }
    }
};

const white_space_property_names = [_][]const u8{ "white-space", "white-space-collapse", "text-wrap-mode", "text-wrap" };

/// Gecko's AutoMoveOneLineHandler::ConsiderWhetherPreserveWhiteSpaceStyle:
/// a join from or into a <pre> keeps no white-space style, as every browser
/// does for a <pre> styled by the UA sheet alone - but where an AUTHOR
/// declaration sets that white-space, Chrome 155 and Safari 27 keep it
/// (`<div>abc[]</div><pre>def</pre>` with `pre { white-space: pre }` ->
/// `<div>abc<span style="white-space:pre">def</span></div>`), which Gecko's
/// TODO there names as its target ("If `white-space` is specified by non-UA
/// stylesheet, we should preserve it even if the right block is <pre> for
/// compatibility with the other browsers"; mozilla-firefox/firefox main,
/// editor/libeditor/HTMLEditorDeleteHandler.cpp, 2026-10-26).
/// editing/other/join-pre-and-other-block.html at wpt.fyi df642c4142:
/// Chrome 46/46, Firefox 28/46, Safari 46/46 (the ?method=backspace&block=div
/// variant; the others alike). Majority with Gecko's stated target.
fn considerPreservingWhiteSpace(content_in_line: *Instance, destination: *Instance) !bool {
    if (try isUserAgentPre(destination)) return false;
    return !try isUserAgentPre(content_in_line);
}

/// Whether `node` is an inclusive descendant of a <pre> whose computed
/// white-space is `pre` and that no author declaration sets on the <pre> or
/// on an element between it and `node`.
fn isUserAgentPre(node: *Instance) !bool {
    const element = if (common.isElement(node)) node else ((try common.parent(node)) orelse return false);
    if (!common.isElement(element)) return false;
    const styles = common.whiteSpaceStylesOf(element) orelse return false;
    if (styles.collapse != .preserve or !styles.nowrap) return false;
    var pre: ?*Instance = element;
    while (pre) |p| : (pre = try common.parent(p)) {
        if (!common.isElement(p)) return false;
        if (try common.isHtmlElementNamed(p, "pre")) break;
    }
    const found = pre orelse return false;
    var current = element;
    while (true) {
        if (try dom.style.engine.authorDeclares(current, &white_space_property_names)) return false;
        if (current == found) return true;
        current = (try common.parent(current)) orelse return false;
    }
}

/// Where a line ends inside one of its top-level nodes: before `node` in
/// `parent` (null: at `parent`'s end).
const LineEnd = struct { parent: *Instance, node: ?*Instance };

/// The first line of a block from its child `first`, isolated: the
/// browsers' line (Chrome and Safari move a block's first line when blocks
/// join, the integrator's ruling 2026-10-23; see the module comment), found
/// on the DOM as Gecko's AutoMoveOneLineHandler does. The line runs through
/// `first` and its following siblings and ends at a block node (before it),
/// a br (removed) or a line feed in text whose white-space preserves
/// segment breaks (the text is split there and the line feed removed). An
/// end inside an inline is isolated by splitting the inline's descendants
/// and the inline itself there (Gecko's SplitNodeDeep; the clones take
/// what follows). Appends the line's top-level nodes - `first` and its
/// following siblings - to `line`.
fn extractFirstLine(edit: *Edit, first: *Instance, line: *Line, lone_br: LoneBr) !void {
    var current: ?*Instance = first;
    while (current) |child| {
        if (common.isBlockNode(child)) return;
        if (try isBr(child)) {
            // A line that is only a br: steps 32 and 33 move it, as the spec
            // does, and their later steps drop it where it is extraneous;
            // step 34 deletes it (the browsers' first line).
            if (child == first and lone_br == .move) {
                try line.nodes.append(edit.allocator, child);
                return;
            }
            try edit.removeNode(child);
            return;
        }
        if (common.isText(child)) {
            if (try splitAtLineFeed(edit, child)) |split| {
                if (split.text_on_line) try line.nodes.append(edit.allocator, child);
                return;
            }
        } else if (common.isElement(child)) {
            if (try findLineEndInside(edit, child)) |end| {
                try splitDeep(edit, child, end.parent, end.node);
                // An inline the line end emptied (it held only the br) is
                // invisible: it goes instead of moving (Gecko's
                // MoveNodeOrChildrenWithTransaction, RemoveIfInvisibleNode).
                if (!try common.hasChildren(child)) {
                    try edit.removeNode(child);
                } else {
                    try line.nodes.append(edit.allocator, child);
                }
                return;
            }
        }
        try line.nodes.append(edit.allocator, child);
        current = try common.nextSibling(child);
    }
}

/// What a line that is only a br does with it.
const LoneBr = enum { move, delete };

/// A Text node split at the line feed that ends a line.
const LineFeedSplit = struct {
    /// Whether the text keeps a part on the line (the line feed was not its
    /// first character).
    text_on_line: bool,
    /// The first node after the line's end at the text's level; null when
    /// nothing follows there.
    after: ?*Instance,
};

/// Split `text` at its first line feed when its white-space preserves
/// segment breaks, removing the line feed (and a Text node it empties);
/// null when it ends no line.
fn splitAtLineFeed(edit: *Edit, text: *Instance) !?LineFeedSplit {
    if (!(try common.whiteSpaceAround(text)).preservesNewlines()) return null;
    var data = try common.textData(text);
    defer data.deinit(text.ctx.allocator);
    const lf = std.mem.indexOfScalar(u8, data.asSlice(), '\n') orelse return null;
    const units = common.utf16Length(data.asSlice()[0..lf]);
    // Text.splitText keeps the first part in place and inserts the rest
    // after it; the line feed starts the rest.
    const rest = if (units == 0) text else try interfaces.Text.call_splitText(text, units);
    if (rest != text) edit.modified = true;
    try edit.deleteData(rest, 0, 1);
    var after: ?*Instance = rest;
    if ((try common.nodeLength(rest)) == 0) {
        after = try common.nextSibling(rest);
        try edit.removeNode(rest);
    }
    return .{ .text_on_line = units != 0, .after = after };
}

/// The end of the line inside `element` (an inline), in tree order: before
/// a descendant block, at a descendant br (removed here), or at a line feed
/// in a descendant text (split and removed here). Null when the line runs
/// through the whole element.
fn findLineEndInside(edit: *Edit, element: *Instance) !?LineEnd {
    var current = try common.firstChild(element);
    while (current) |node| {
        if (!common.isDescendantOf(node, element)) return null;
        const p = (try common.parent(node)).?;
        if (common.isBlockNode(node)) return .{ .parent = p, .node = node };
        if (try isBr(node)) {
            const next = try common.nextSibling(node);
            try edit.removeNode(node);
            return .{ .parent = p, .node = next };
        }
        if (common.isText(node)) {
            if (try splitAtLineFeed(edit, node)) |split| return .{ .parent = p, .node = split.after };
        }
        current = try common.nextInTreeOrder(node);
    }
    return null;
}

/// Split `top` and its descendants down to `parent` at (parent, before `node`):
/// everything from `node` on moves into shallow clones inserted after each
/// split element, so `top` keeps what comes before the point (Gecko's
/// SplitNodeDeepWithTransaction). A level with nothing after the point is
/// not split. The clones drop an id, as "split the parent" step 7.2 keeps
/// it on one element only.
fn splitDeep(edit: *Edit, top: *Instance, parent: *Instance, node: ?*Instance) !void {
    var level = parent;
    var from = node;
    while (true) {
        if (from) |first_moved| {
            const clone = try common.cloneNode(level, false);
            if (try common.hasAttribute(clone, "id")) try common.removeAttribute(clone, "id");
            const grandparent = (try common.parent(level)) orelse return;
            try edit.insertBefore(grandparent, clone, try common.nextSibling(level));
            var moving: ?*Instance = first_moved;
            while (moving) |m| {
                const next = try common.nextSibling(m);
                try edit.movePreservingRanges(m, clone, try common.childCount(clone));
                moving = next;
            }
        }
        if (level == top) return;
        from = try common.nextSibling(level);
        level = (try common.parent(level)) orelse return;
    }
}

fn hasVisibleChild(node: *Instance) !bool {
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (try common.isVisible(c)) return true;
    }
    return false;
}

/// Whether `node` and its next sibling are both ol or both ul, in the same
/// editing host.
fn isListFollowedByList(node: *Instance) !bool {
    const next = (try common.nextSibling(node)) orelse return false;
    inline for (.{ "ol", "ul" }) |name| {
        if ((try common.isHtmlElementNamed(node, name)) and (try common.isHtmlElementNamed(next, name)) and try common.inSameEditingHost(node, next)) return true;
    }
    return false;
}

/// Step 37's condition: an inclusive ancestor list (in the same editing host
/// as `node`) whose next sibling is a list of the same kind.
fn hasMergeableListAncestor(node: *Instance) !bool {
    var current: ?*Instance = node;
    while (current) |c| : (current = try common.parent(c)) {
        if (!try common.inSameEditingHost(node, c)) return false;
        if (try isListFollowedByList(c)) return true;
    }
    return false;
}

/// The "delete" command's action. Returns the action's result.
pub fn deleteAction(edit: *Edit) !bool {
    // Step 1.
    if (!try edit.rangeCollapsed()) {
        try deleteTheSelection(edit, true, true, .forward);
        return true;
    }
    edit.range_from_caret = true;
    // Browser step (golden rule 2, no newer spec): with nothing visible
    // between the editing host's start and the caret - only collapsed
    // white-space, invisible nodes and the caret's own block's start -
    // Backspace does nothing at all. Chrome 156, Firefox 158 and Safari 27
    // leave `<div> []abc</div>` and `<div> [] abc</div>` unchanged
    // (editing/run/delete.html ?6001-7000 at wpt.fyi c645564b0e); the spec's
    // step 2 would strip the collapsed spaces. Blink finds no previous
    // VisiblePosition in the editable; Gecko's WSRunScanner reaches the
    // editing host's start. A block boundary before the caret is content:
    // the merge goes on as the spec says.
    {
        const caret = (try edit.rangeStart()) orelse return true;
        const host = (try common.editingHostOf(caret.node)) orelse return true;
        if (!try hasVisibleContentBefore(caret, host)) return true;
    }
    // Step 2.
    try whitespace.canonicalizeWhitespace(edit, (try edit.rangeStart()) orelse return true, true);
    // Step 3.
    var point = (try edit.rangeStart()) orelse return true;
    // Step 4: up to the block, then down to the deepest end.
    while (true) {
        // Step 4.1.
        if (point.offset == 0) {
            if (try common.previousSibling(point.node)) |previous| {
                if ((try common.isEditable(previous)) and try common.isInvisible(previous)) {
                    try edit.removeNode(previous);
                    continue;
                }
            }
        }
        // Step 4.2.
        if (try common.childBefore(point.node, point.offset)) |child| {
            if ((try common.isEditable(child)) and try common.isInvisible(child)) {
                try edit.removeNode(child);
                point.offset -= 1;
                continue;
            }
        }
        // Step 4.3.
        if ((point.offset == 0 and common.isInlineNode(point.node)) or try common.isInvisible(point.node)) {
            const p = (try common.parent(point.node)) orelse break;
            point = try common.pointBefore(point.node, p);
            continue;
        }
        // Step 4.4: a link before the caret is removed whole.
        if (try common.childBefore(point.node, point.offset)) |child| {
            if ((try common.isEditable(child)) and try common.isHtmlElementNamed(child, "a")) {
                try split_parent.removePreservingDescendants(edit, child);
                return true;
            }
        }
        // Step 4.5.
        if (try common.childBefore(point.node, point.offset)) |child| {
            if (!common.isBlockNode(child) and !(try isBr(child)) and !(try common.isHtmlElementNamed(child, "img"))) {
                point = .{ .node = child, .offset = try common.nodeLength(child) };
                continue;
            }
        }
        // Step 4.6.
        break;
    }
    // Step 5: a character, or a br, hr or img.
    if ((common.isText(point.node) and point.offset != 0) or
        (common.isBlockNode(point.node) and try childBeforeIsNamed(point, &.{ "br", "hr", "img" })))
    {
        try edit.collapse(point.node, point.offset);
        try edit.extend(point.node, point.offset - 1);
        try deleteTheSelection(edit, true, true, .forward);
        return true;
    }
    // Step 6.
    if (common.isInlineNode(point.node)) return true;
    // Step 10 outdents the start of an indentation element. The browsers
    // do that only where there is no previous line to join with; with one,
    // the line joins it like any other block (golden rule 2, no newer spec;
    // integrator ruling 2026-10-26): Chrome 156, Firefox 158 and Safari 27
    // all give `foo<blockquote>[]bar</blockquote>` -> `foobar`
    // (editing/run/delete.html) and join `<pre>abc</pre><blockquote>[]def
    // </blockquote>` into `<pre>abcdef</pre>`
    // (editing/other/join-pre-and-other-block.html), wpt.fyi 5af3c135c9,
    // where the data file expects the spec's outdent.
    const joins_previous_line = blk: {
        const host = (try common.editingHostOf(point.node)) orelse break :blk false;
        break :blk try hasVisibleContentBefore(point, host);
    };
    // Step 7: the first item of a list outdents. Spec kept: all three
    // browsers join this line into the previous one too (`foo<ol><li>[]bar
    // <li>baz</ol>` -> `foobar<ol><li>baz</li></ol>`), but following them
    // would lose 6 subtests that pass on the spec's outdent (never-trade;
    // integrator ruling 2026-10-26): `foo<dl><dt>[]bar<dd>baz</dl>` and
    // `foo<dl><dd>[]bar</dl>` under both separators, where Crane would then
    // match all three browsers but not the data, and `foo<ol><ol><li>[]bar
    // </ol></ol>` and `foo<blockquote><ol><li>bar</li><ol><li>[]baz</ol>
    // <li>quz</ol></blockquote>`, where Firefox 158 matches the data
    // (editing/run/delete.html, wpt.fyi 5af3c135c9).
    if ((try common.isHtmlElementIn(point.node, &list_item_names)) and point.offset == 0) {
        if (try common.parent(point.node)) |p| {
            if ((try common.firstChild(p)) == point.node) {
                // Steps 7.1-7.2.
                var ancestor = try common.parent(point.node);
                while (ancestor) |a| : (ancestor = try common.parent(a)) {
                    if (try common.isHtmlElementNamed(a, "li")) try lists.normalizeSublists(edit, a);
                }
                // Steps 7.3-7.5.
                const values = try overrides.recordTheValues(edit, &.{point.node});
                try split_parent.splitParent(edit, &.{point.node});
                try overrides.restoreTheValues(edit, values);
                // Step 7.6.
                var node = point.node;
                if ((try common.isHtmlElementIn(node, &.{ "dd", "dt" })) and !try isAllowedChildOfAnAncestorInHost(node)) {
                    node = try edit.setTagName(node, try block_formatting.defaultSingleLineContainerName(edit));
                }
                // Step 7.7.
                try block_formatting.fixDisallowedAncestors(edit, node);
                // Step 7.8.
                return true;
            }
        }
    }
    // Step 8.
    var start = point;
    // Step 9.
    while (true) {
        if (start.offset == 0) {
            const p = (try common.parent(start.node)) orelse break;
            start = try common.pointBefore(start.node, p);
            continue;
        }
        if (try common.childBefore(start.node, start.offset)) |child| {
            if ((try common.isEditable(child)) and try common.isInvisible(child)) {
                try edit.removeNode(child);
                start.offset -= 1;
                continue;
            }
        }
        break;
    }
    // Step 10: at the start of an indentation element, outdent - unless
    // there is a previous line to join (above).
    if (!joins_previous_line and point.offset == 0) {
        var current: ?*Instance = point.node;
        while (current) |c| : (current = try common.parent(c)) {
            if ((try common.isEditable(c)) and (try common.inSameEditingHost(point.node, c)) and try common.isIndentationElement(c)) {
                try indent.outdentAtIndentationElement(edit, point.node);
                return true;
            }
        }
    }
    // Step 11: a table after the point: nothing.
    if (try common.childAt(start.node, start.offset)) |child| {
        if (try common.isHtmlElementNamed(child, "table")) return true;
    }
    // Step 12: a table before the point is selected.
    if (try common.childBefore(start.node, start.offset)) |child| {
        if (try common.isHtmlElementNamed(child, "table")) {
            try edit.collapse(start.node, start.offset - 1);
            try edit.extend(start.node, start.offset);
            return true;
        }
    }
    // Step 13: an hr, or a br after a br or a block, is deleted on its own.
    if (point.offset == 0) {
        if (try common.childBefore(start.node, start.offset)) |child| {
            var special = try common.isHtmlElementNamed(child, "hr");
            if (!special and try isBr(child)) {
                if (try common.previousSibling(child)) |previous| {
                    special = (try isBr(previous)) or !common.isInlineNode(previous);
                }
            }
            if (special) {
                try edit.collapse(start.node, start.offset - 1);
                try edit.extend(start.node, start.offset);
                try deleteTheSelection(edit, true, true, .forward);
                try edit.collapse(point.node, point.offset);
                return true;
            }
            // The browsers go further (golden rule 2, no newer spec): at the
            // start of a block, a line break before it that makes an empty
            // line of its own - a br or a preserved line feed at a line
            // start, at the end of what precedes the block, inside inlines
            // too - is deleted alone and the block stays, the caret in it:
            // `<br><div>[]def</div>` -> `<div>def</div>`,
            // `<b>abc<br><br></b><div>[]def</div>` -> `<b>abc<br></b><div>def</div>`.
            // Gecko's AutoBlockElementsJoiner modes
            // DeletePrecedingBRElementOfBlock and
            // DeletePrecedingPreformattedLineBreak (editor/libeditor/
            // HTMLEditorDeleteHandler.cpp, mozilla-firefox/firefox
            // 6cb22fec8a1e); editing/other/delete-without-unwrapping-first-
            // line-of-child-block.html, passed by Chrome 155 and Firefox 158
            // (wpt.fyi df642c4142). A br that only ends the line before
            // (`foo<br><p>[]bar</p>`) still joins.
            if (common.isBlockNode(point.node)) {
                if (try emptyLineBreakBefore(child)) |line_break| {
                    switch (line_break) {
                        .br => |br| {
                            const p = (try common.parent(br)).?;
                            const index = try common.indexOf(br);
                            try edit.collapse(p, index);
                            try edit.extend(p, index + 1);
                        },
                        .line_feed => |text| {
                            const length = try common.nodeLength(text);
                            try edit.collapse(text, length - 1);
                            try edit.extend(text, length);
                        },
                    }
                    try deleteTheSelection(edit, true, true, .forward);
                    try edit.collapse(point.node, point.offset);
                    return true;
                }
            }
        }
    }
    // Step 14: backspacing out of a list item adds a line break first.
    if (try common.childAt(start.node, start.offset)) |child| {
        if ((try common.isHtmlElementIn(child, &list_item_names)) and start.offset != 0) {
            if (try common.firstChild(child)) |child_first| {
                if (common.isInlineNode(child_first)) {
                    // Step 14.1.
                    const previous_item = (try common.childBefore(start.node, start.offset)).?;
                    // Step 14.2.
                    if (try common.lastChild(previous_item)) |last| {
                        if (common.isInlineNode(last) and !try isBr(last)) {
                            const br = try edit.createElement("br");
                            try edit.appendChild(previous_item, br);
                        }
                    }
                    // Step 14.3.
                    if (try common.lastChild(previous_item)) |last| {
                        if (common.isInlineNode(last)) {
                            const br = try edit.createElement("br");
                            try edit.appendChild(previous_item, br);
                        }
                    }
                }
            }
        }
    }
    // Step 15: adjacent list items merge themselves, not their blocks.
    if (try common.childAt(start.node, start.offset)) |child| {
        if (try common.isHtmlElementIn(child, &list_item_names)) {
            if (try common.previousSibling(child)) |previous| {
                if (try common.isHtmlElementIn(previous, &list_item_names)) {
                    // Step 15.1.
                    const original_range = try interfaces.Range.call_cloneRange((try edit.activeRange()).?);
                    // Steps 15.2-15.4.
                    start = .{ .node = previous, .offset = try common.nodeLength(previous) };
                    const node = (try common.nextSibling(previous)).?;
                    // Steps 15.5-15.7.
                    try edit.collapse(start.node, start.offset);
                    try edit.extend(node, 0);
                    try deleteTheSelection(edit, true, true, .forward);
                    // Steps 15.8-15.9.
                    try interfaces.Selection.call_removeAllRanges(edit.selection);
                    try interfaces.Selection.call_addRange(edit.selection, original_range);
                    // Step 15.10.
                    return true;
                }
            }
        }
    }
    // Step 16: the general block merge - down to the previous block's end.
    while (try common.childBefore(start.node, start.offset)) |child| {
        if ((try common.isEditable(child)) and try common.isInvisible(child)) {
            try edit.removeNode(child);
            start.offset -= 1;
        } else {
            start = .{ .node = child, .offset = try common.nodeLength(child) };
        }
    }
    // Steps 17-18.
    try edit.collapse(start.node, start.offset);
    try edit.extend(point.node, point.offset);
    // Step 19.
    try deleteTheSelection(edit, true, true, .backward);
    // Step 20.
    return true;
}

/// The "forwardDelete" command's action.
pub fn forwardDeleteAction(edit: *Edit) !bool {
    // Step 1.
    if (!try edit.rangeCollapsed()) {
        try deleteTheSelection(edit, true, true, .forward);
        return true;
    }
    edit.range_from_caret = true;
    // Browser step: with nothing visible between the caret and the editing
    // host's end, Delete does nothing. Chrome 156 and Safari 27 leave
    // `<div>abc[] </div>` and `<div>abc [] </div>` unchanged; Firefox 158
    // strips the spaces (editing/run/forwarddelete.html ?6001-7000 at
    // wpt.fyi c645564b0e): the majority. See the delete action.
    {
        const caret = (try edit.rangeStart()) orelse return true;
        const host = (try common.editingHostOf(caret.node)) orelse return true;
        if (!try hasVisibleContentAfter(caret, host)) return true;
    }
    // Step 2.
    try whitespace.canonicalizeWhitespace(edit, (try edit.rangeStart()) orelse return true, true);
    // Step 3.
    var point = (try edit.rangeStart()) orelse return true;
    // Step 4.
    while (true) {
        const length = try common.nodeLength(point.node);
        // Step 4.1.
        if (point.offset == length) {
            if (try common.nextSibling(point.node)) |next| {
                if ((try common.isEditable(next)) and try common.isInvisible(next)) {
                    try edit.removeNode(next);
                    continue;
                }
            }
        }
        // Step 4.2.
        if (try common.childAt(point.node, point.offset)) |child| {
            if ((try common.isEditable(child)) and try common.isInvisible(child)) {
                try edit.removeNode(child);
                continue;
            }
        }
        // Step 4.3.
        if ((point.offset == length and common.isInlineNode(point.node)) or try common.isInvisible(point.node)) {
            const p = (try common.parent(point.node)) orelse break;
            point = try common.pointAfter(point.node, p);
            continue;
        }
        // Step 4.4.
        if (try common.childAt(point.node, point.offset)) |child| {
            if (!common.isBlockNode(child) and !(try isBr(child)) and !(try common.isHtmlElementNamed(child, "img")) and !try common.isCollapsedBlockProp(child)) {
                point = .{ .node = child, .offset = 0 };
                continue;
            }
        }
        // Step 4.5.
        break;
    }
    // The browsers' empty line before a block (see deleteEmptyLineBeforeBlock).
    if (try deleteEmptyLineBeforeBlock(edit, point)) return true;
    // Step 5: a character and its combining marks.
    if (common.isText(point.node) and point.offset != try common.nodeLength(point.node)) {
        // Step 5.1.
        var end_offset = point.offset + 1;
        // Step 5.2: the following marks (general category M) go too.
        {
            var data = try common.textData(point.node);
            defer data.deinit(point.node.ctx.allocator);
            const length = common.utf16Length(data.asSlice());
            while (end_offset != length) : (end_offset += 1) {
                const code_point = common.codePointAt(data.asSlice(), end_offset) orelse break;
                if (!unicode_data.isMark(code_point)) break;
            }
        }
        // Steps 5.3-5.6.
        try edit.collapse(point.node, point.offset);
        try edit.extend(point.node, end_offset);
        try deleteTheSelection(edit, true, true, .forward);
        return true;
    }
    // Step 6.
    if (common.isInlineNode(point.node)) return true;
    // Step 7: a br, hr or img that is not a collapsed block prop.
    if (try common.childAt(point.node, point.offset)) |child| {
        if ((try common.isHtmlElementIn(child, &.{ "br", "hr", "img" })) and !try common.isCollapsedBlockProp(child)) {
            try edit.collapse(point.node, point.offset);
            try edit.extend(point.node, point.offset + 1);
            try deleteTheSelection(edit, true, true, .forward);
            return true;
        }
    }
    // Step 8.
    var end = point;
    // Step 9.
    if (try common.childAt(end.node, end.offset)) |child| {
        if (try common.isCollapsedBlockProp(child)) end.offset += 1;
    }
    // Step 10.
    while (true) {
        if (end.offset == try common.nodeLength(end.node)) {
            const p = (try common.parent(end.node)) orelse break;
            end = try common.pointAfter(end.node, p);
            continue;
        }
        if (try common.childAt(end.node, end.offset)) |child| {
            if ((try common.isEditable(child)) and try common.isInvisible(child)) {
                try edit.removeNode(child);
                continue;
            }
        }
        break;
    }
    // Step 11: a table before the point: nothing.
    if (try common.childBefore(end.node, end.offset)) |child| {
        if (try common.isHtmlElementNamed(child, "table")) return true;
    }
    // Step 12: a table after the point is selected.
    if (try common.childAt(end.node, end.offset)) |child| {
        if (try common.isHtmlElementNamed(child, "table")) {
            try edit.collapse(end.node, end.offset);
            try edit.extend(end.node, end.offset + 1);
            return true;
        }
    }
    // Step 13: an hr or br right after a block is deleted on its own.
    if (point.offset == try common.nodeLength(point.node)) {
        if (try common.childAt(end.node, end.offset)) |child| {
            if (try common.isHtmlElementIn(child, &.{ "hr", "br" })) {
                try edit.collapse(end.node, end.offset);
                try edit.extend(end.node, end.offset + 1);
                try deleteTheSelection(edit, true, true, .forward);
                try edit.collapse(point.node, point.offset);
                return true;
            }
        }
    }
    // Step 14: down to the next block's start.
    while (try common.childAt(end.node, end.offset)) |child| {
        if ((try common.isEditable(child)) and try common.isInvisible(child)) {
            try edit.removeNode(child);
        } else {
            end = .{ .node = child, .offset = 0 };
        }
    }
    // Steps 15-16.
    try edit.collapse(point.node, point.offset);
    try edit.extend(end.node, end.offset);
    // Step 17.
    try deleteTheSelection(edit, true, true, .forward);
    // Step 18.
    return true;
}

/// Whether `node`, met on a walk away from the caret, is content: a block
/// boundary, a br, img or hr, or text that is not collapsible white-space.
/// Display: none subtrees and inline containers are not.
fn isContentOnTheLine(node: *Instance) !bool {
    if (try common.hasDisplayNoneInclusiveAncestor(node)) return false;
    if (common.isBlockNode(node)) return true;
    if (try common.isHtmlElementIn(node, &.{ "br", "img", "hr" })) return true;
    return common.isText(node) and !try common.isWhitespaceNode(node);
}

/// Whether anything visible lies between `host`'s start and `point`.
fn hasVisibleContentBefore(point: Point, host: *Instance) !bool {
    if (common.isText(point.node)) {
        if (point.offset > 0 and !try common.textIsCollapsibleWhitespace(point.node, 0, point.offset)) return true;
    } else {
        var index: u32 = 0;
        var child = try common.firstChild(point.node);
        while (child) |c| : (child = try common.nextSibling(c)) {
            if (index >= point.offset) break;
            if (try common.isVisible(c)) return true;
            index += 1;
        }
    }
    var current = point.node;
    while (current != host) {
        const previous = (try common.previousInTreeOrder(current)) orelse return false;
        if (previous == host or !common.isInclusiveDescendantOf(previous, host)) return false;
        current = previous;
        // The caret's ancestors are around it, not before it.
        if (common.isAncestorOf(previous, point.node)) continue;
        if (try isContentOnTheLine(previous)) return true;
    }
    return false;
}

/// Whether anything visible lies between `point` and `host`'s end.
fn hasVisibleContentAfter(point: Point, host: *Instance) !bool {
    if (common.isText(point.node)) {
        const length = try common.nodeLength(point.node);
        if (point.offset < length and !try common.textIsCollapsibleWhitespace(point.node, point.offset, length)) return true;
    } else {
        var child = try common.childAt(point.node, point.offset);
        while (child) |c| : (child = try common.nextSibling(c)) {
            if (try common.isVisible(c)) return true;
        }
    }
    if (point.node == host) return false;
    var current = try common.nextSkippingChildren(point.node);
    while (current) |node| {
        if (!common.isDescendantOf(node, host)) return false;
        if (try isContentOnTheLine(node)) return true;
        // A hidden subtree is skipped whole.
        current = if (isElementDisplayNone(node)) try common.nextSkippingChildren(node) else try common.nextInTreeOrder(node);
    }
    return false;
}

fn isElementDisplayNone(node: *Instance) bool {
    return common.isElement(node) and common.displayIsNone(node);
}

fn childBeforeIsNamed(point: Point, names: []const []const u8) !bool {
    const child = (try common.childBefore(point.node, point.offset)) orelse return false;
    return try common.isHtmlElementIn(child, names);
}

/// Whether `node` is an allowed child of some ancestor in its editing host.
fn isAllowedChildOfAnAncestorInHost(node: *Instance) !bool {
    var current = try common.parent(node);
    while (current) |c| : (current = try common.parent(c)) {
        if (!try common.inSameEditingHost(node, c)) break;
        if (try common.isAllowedChild(.{ .node = node }, c)) return true;
    }
    return false;
}
