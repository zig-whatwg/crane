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
const overrides = @import("overrides.zig");

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
    // Steps 4-5.
    var start = try common.lastEquivalentPoint((try edit.rangeStart()) orelse return);
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
    // Steps 18-19.
    const recorded = try overrides.recordCurrentStatesAndValues(edit);
    // Step 21: one editable Text node.
    if (start.node == end.node and common.isText(start.node) and try common.isEditable(start.node)) {
        try edit.deleteData(start.node, start.offset, end.offset - start.offset);
        try whitespace.canonicalizeWhitespace(edit, start, false);
        if (direction == .forward) try edit.collapseToStart() else try edit.collapseToEnd();
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
        // Step 25.4: strip the emptied inline wrappers.
        if (strip_wrappers or !common.isInclusiveDescendantOf(start.node, p)) {
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
        if (direction == .forward) try edit.collapseToStart() else try edit.collapseToEnd();
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
        // Steps 32.6-32.8: the end block's first line.
        var children: std.ArrayList(*Instance) = .empty;
        defer children.deinit(edit.allocator);
        try children.append(edit.allocator, (try common.firstChild(eb)).?);
        while (!(try isBr(children.items[children.items.len - 1]))) {
            const next = (try common.nextSibling(children.items[children.items.len - 1])) orelse break;
            if (!common.isInlineNode(next)) break;
            try children.append(edit.allocator, next);
        }
        // Step 32.9.
        values = try overrides.recordTheValues(edit, children.items);
        // Step 32.10.
        while ((try common.parent(children.items[0])) != sb) {
            try split_parent.splitParent(edit, children.items);
        }
        // Step 32.11.
        if (try common.previousSibling(children.items[0])) |previous| {
            if ((try common.isEditable(previous)) and try isBr(previous)) try edit.removeNode(previous);
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
        // Steps 33.5-33.7.
        var nodes_to_move: std.ArrayList(*Instance) = .empty;
        defer nodes_to_move.deinit(edit.allocator);
        if (try common.nextSibling(reference)) |next| {
            if (!common.isBlockNode(next)) try nodes_to_move.append(edit.allocator, next);
        }
        while (nodes_to_move.items.len > 0 and !try isBr(nodes_to_move.items[nodes_to_move.items.len - 1])) {
            const next = (try common.nextSibling(nodes_to_move.items[nodes_to_move.items.len - 1])) orelse break;
            if (common.isBlockNode(next)) break;
            try nodes_to_move.append(edit.allocator, next);
        }
        // Step 33.8.
        values = try overrides.recordTheValues(edit, nodes_to_move.items);
        // Step 33.9.
        for (nodes_to_move.items) |node| {
            try edit.movePreservingRanges(node, sb, try common.childCount(sb));
        }
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
        try moveFirstLine(edit, eb, sb);
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

/// Step 34.4 under the first-line rule: move `end_block`'s first child and
/// the inline siblings after it into `start_block`, up to the line's end -
/// a br (deleted), a block node, or a line feed in text whose white-space
/// preserves segment breaks (the text is split there and the LF deleted).
fn moveFirstLine(edit: *Edit, end_block: *Instance, start_block: *Instance) !void {
    while (try common.firstChild(end_block)) |child| {
        if (common.isBlockNode(child)) return;
        if (try isBr(child)) {
            try edit.removeNode(child);
            return;
        }
        if (common.isText(child) and (try common.whiteSpaceAround(child)).preservesNewlines()) {
            var data = try common.textData(child);
            defer data.deinit(child.ctx.allocator);
            if (std.mem.indexOfScalar(u8, data.asSlice(), '\n')) |lf| {
                const units = common.utf16Length(data.asSlice()[0..lf]);
                if (units == 0) {
                    try edit.deleteData(child, 0, 1);
                    return;
                }
                // Text.splitText keeps the first part in place and inserts
                // the rest after it; the first part moves, the LF goes.
                const rest = try interfaces.Text.call_splitText(child, units);
                edit.modified = true;
                try edit.movePreservingRanges(child, start_block, try common.childCount(start_block));
                try edit.deleteData(rest, 0, 1);
                return;
            }
        }
        try edit.movePreservingRanges(child, start_block, try common.childCount(start_block));
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
    // Step 7: the first item of a list outdents.
    if ((try common.isHtmlElementIn(point.node, &list_item_names)) and point.offset == 0) {
        if (try common.parent(point.node)) |p| {
            if ((try common.firstChild(p)) == point.node) {
                // Steps 7.1-7.2.
                var ancestor = try common.parent(point.node);
                while (ancestor) |a| : (ancestor = try common.parent(a)) {
                    if (try common.isHtmlElementNamed(a, "li")) try overrides.normalizeSublists(edit, a);
                }
                // Steps 7.3-7.5.
                const values = try overrides.recordTheValues(edit, &.{point.node});
                try split_parent.splitParent(edit, &.{point.node});
                try overrides.restoreTheValues(edit, values);
                // Step 7.6.
                var node = point.node;
                if ((try common.isHtmlElementIn(node, &.{ "dd", "dt" })) and !try isAllowedChildOfAnAncestorInHost(node)) {
                    node = try edit.setTagName(node, try defaultSingleLineContainerName(edit));
                }
                // Step 7.7.
                try overrides.fixDisallowedAncestors(edit, node);
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
    // Step 10: at the start of an indentation element, outdent.
    if (point.offset == 0) {
        var current: ?*Instance = point.node;
        while (current) |c| : (current = try common.parent(c)) {
            if ((try common.isEditable(c)) and (try common.inSameEditingHost(point.node, c)) and try common.isIndentationElement(c)) {
                try overrides.outdentAtIndentationElement(edit, point.node);
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

/// The document's "default single-line container name": the
/// defaultParagraphSeparator command's value, "div" when unset.
fn defaultSingleLineContainerName(edit: *Edit) ![]const u8 {
    var value = try interfaces.Document.call_queryCommandValue(edit.document, runtime.DOMString.initInterned("defaultParagraphSeparator"));
    defer value.deinit(edit.document.ctx.allocator);
    return if (std.mem.eql(u8, value.asSlice(), "p")) "p" else "div";
}
