//! Lists (specs/w3c/execCommand.md): "normalize sublists", "the selection's
//! list state" and "Toggling lists" - the insertOrderedList and
//! insertUnorderedList commands' action, state and indeterminacy - step by
//! step.

const std = @import("std");
const common = @import("common.zig");
const block = @import("block.zig");
const split_parent = @import("split_parent.zig");
const overrides = @import("overrides.zig");
const indent = @import("indent.zig");
const wrap_mod = @import("wrap.zig");

const Edit = common.Edit;
const Point = common.Point;
const Instance = common.Instance;

fn isList(node: *Instance) !bool {
    return try common.isHtmlElementIn(node, &.{ "ol", "ul" });
}

fn parentIsList(node: *Instance) !bool {
    const p = (try common.parent(node)) orelse return false;
    return try isList(p);
}

/// "normalize sublists" in `item`: an li's ol and ul children, and what
/// follows them, move out after it.
pub fn normalizeSublists(edit: *Edit, item: *Instance) !void {
    // Step 1.
    if (!try common.isHtmlElementNamed(item, "li")) return;
    if (!try common.isEditable(item)) return;
    const item_parent = (try common.parent(item)) orelse return;
    if (!try common.isEditable(item_parent)) return;
    // Step 2.
    var new_item: ?*Instance = null;
    // Step 3.
    while (try hasListChild(item)) {
        // Step 3.1.
        const child = (try common.lastChild(item)).?;
        // Step 3.2.
        if ((try isList(child)) or (new_item == null and common.isText(child) and try isSpaceText(child))) {
            // Step 3.2.1.
            new_item = null;
            // Step 3.2.2.
            const p = (try common.parent(item)) orelse return;
            try edit.movePreservingRanges(child, p, 1 + try common.indexOf(item));
        } else {
            // Step 3.3.1.
            if (new_item == null) {
                const created = try edit.createElement("li");
                const p = (try common.parent(item)) orelse return;
                try edit.insertBefore(p, created, try common.nextSibling(item));
                new_item = created;
            }
            // Step 3.3.2.
            try edit.movePreservingRanges(child, new_item.?, 0);
        }
    }
}

fn hasListChild(node: *Instance) !bool {
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (try isList(c)) return true;
    }
    return false;
}

/// A Text node whose data is zero or more ASCII whitespace.
fn isSpaceText(node: *Instance) !bool {
    var data = try common.textData(node);
    defer data.deinit(node.ctx.allocator);
    for (data.asSlice()) |byte| switch (byte) {
        ' ', '\t', '\n', '\x0C', '\r' => {},
        else => return false,
    };
    return true;
}

/// The lis that are inclusive ancestors of the active range's start and/or
/// end node, in tree order (the indent, outdent and toggle lists commands'
/// step "Let items be ..."), normalized: "For each item in items, normalize
/// sublists of item."
pub fn normalizeItemsAroundActiveRange(edit: *Edit) !void {
    const start = (try edit.rangeStart()) orelse return;
    const end = (try edit.rangeEnd()) orelse return;
    var items: std.ArrayList(*Instance) = .empty;
    defer items.deinit(edit.allocator);
    // The common ancestor and above, outermost first; then the start's
    // branch below it; then the end's (tree order, as the reference
    // implementation builds it).
    var ancestor = start.node;
    while (!common.isInclusiveDescendantOf(end.node, ancestor)) ancestor = (try common.parent(ancestor)) orelse break;
    try collectItems(edit, ancestor, null, &items);
    try collectItems(edit, start.node, ancestor, &items);
    if (end.node != start.node) try collectItems(edit, end.node, ancestor, &items);
    for (items.items) |item| try normalizeSublists(edit, item);
}

/// Append the lis from `from` up to (not including) `stop`, outermost
/// first.
fn collectItems(edit: *Edit, from: *Instance, stop: ?*Instance, items: *std.ArrayList(*Instance)) !void {
    const at = items.items.len;
    var current: ?*Instance = from;
    while (current) |c| : (current = try common.parent(c)) {
        if (c == stop) break;
        if (try common.isHtmlElementNamed(c, "li")) {
            if (std.mem.indexOfScalar(*Instance, items.items, c) == null) try items.insert(edit.allocator, at, c);
        }
    }
}

/// "the selection's list state".
pub const ListState = enum { none, ol, ul, mixed, mixed_ol, mixed_ul };

/// A list member "ol-like" for the list state: an ol, the child of an ol,
/// or the child of an li child of an ol (and the same for ul).
fn isListish(node: *Instance, name: []const u8) !bool {
    if (try common.isHtmlElementNamed(node, name)) return true;
    const p = (try common.parent(node)) orelse return false;
    if (try common.isHtmlElementNamed(p, name)) return true;
    if (!try common.isHtmlElementNamed(p, "li")) return false;
    const grandparent = (try common.parent(p)) orelse return false;
    return try common.isHtmlElementNamed(grandparent, name);
}

/// Whether `node` is an ancestor of an HTML element named `name`.
fn isAncestorOfNamed(node: *Instance, name: []const u8) !bool {
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (try common.isHtmlElementNamed(c, name)) return true;
        if (try isAncestorOfNamed(c, name)) return true;
    }
    return false;
}

/// The list state's "some member" test of steps 8-10: an ol (ul), or the
/// child or ancestor of one, or the child of an li child of one.
fn isSomeListish(node: *Instance, name: []const u8) !bool {
    return (try isListish(node, name)) or try isAncestorOfNamed(node, name);
}

pub fn selectionListState(edit: *Edit) !ListState {
    return listState(edit, true);
}

/// The list a caret's queries answer: the ol or ul whose editable list item
/// is the caret's nearest li, or null (the spec's state decides). All three
/// browsers answer from the item that holds the caret: Blink's
/// SelectionListState, for a caret, "EnclosingElementWithTag(start,
/// tag_name)" (third_party/blink/renderer/core/editing/commands/
/// editor_command.cc, chromium 1f3d2bc10d1; WebKit's selectionListState the
/// same), Gecko's ListElementSelectionState an li's parent list. The spec's
/// block-extension climbs past a wrapper whose edges meet the list's and
/// answers "mixed": `<div><ol><li>abc[]</li></ol></div>` - what all three
/// browsers make of `<div>{}<br></div>` + insertOrderedList + "abc" - is
/// queryCommandState true and queryCommandIndeterm false in Chrome 157,
/// Firefox 160 and Safari 27.2 (editing/run/insertorderedlist.html,
/// wpt.fyi 2358bd4835). Golden rule 2, no newer spec.
fn caretItemList(edit: *Edit) !?ListState {
    if (!try edit.rangeCollapsed()) return null;
    const caret = (try edit.rangeStart()) orelse return null;
    var current: ?*Instance = caret.node;
    while (current) |c| : (current = try common.parent(c)) {
        if (!try common.isHtmlElementNamed(c, "li")) continue;
        if (!try common.isEditable(c)) return null;
        const list = (try common.parent(c)) orelse return null;
        if (try common.isHtmlElementNamed(list, "ol")) return .ol;
        if (try common.isHtmlElementNamed(list, "ul")) return .ul;
        return null;
    }
    return null;
}

/// The list state, `for_query` applying the browsers' rules of the queries
/// (a caret's list item, caretItemList; table cells, below); toggle lists'
/// own mode (its step 1) is the spec's state, so a second insertOrderedList
/// over two cells' lists takes both out, as the browsers do.
fn listState(edit: *Edit, for_query: bool) !ListState {
    if (for_query) {
        if (try caretItemList(edit)) |state| return state;
    }
    // Steps 1-2 (a table cell bounds the extension, see
    // extendedActiveRange).
    const range = (try extendedActiveRange(edit)) orelse return .none;
    // Steps 3-4.
    var node_list: std.ArrayList(*Instance) = .empty;
    defer node_list.deinit(edit.allocator);
    var walk = try block.ContainedWalk.init(range);
    while (try walk.next()) |node| {
        if (block.lastIsAncestorOf(node_list.items, node)) continue;
        if (!try common.isEditable(node)) continue;
        if (try common.isIndentationElement(node)) continue;
        const kind = (try isList(node)) or (try parentIsList(node)) or try block.isAllowedChildOfName(.{ .node = node }, "li");
        if (!kind) continue;
        try node_list.append(edit.allocator, node);
    }
    // Step 5.
    if (node_list.items.len == 0) return .none;
    // Lists in different table cells are never one list: Chrome 156,
    // Firefox 158 and Safari 27 all answer false for a selection across two
    // cells that each hold an ol (editing/run/insert-list-items-in-table-cell
    // .html, wpt.fyi 5af3c135c9; Blink/WebKit SelectionListState require the
    // selection's start and end in the same list).
    if (for_query) {
        const first_cell = try tableCellOf(node_list.items[0]);
        for (node_list.items[1..]) |member| {
            if ((try tableCellOf(member)) != first_cell) return .none;
        }
    }
    // Step 6.
    var all_ol = true;
    var all_ul = true;
    for (node_list.items) |node| {
        if (!try isListish(node, "ol")) all_ol = false;
        if ((try common.isHtmlElementNamed(node, "ul")) or try isAncestorOfNamed(node, "ul")) all_ol = false;
        if (!try isListish(node, "ul")) all_ul = false;
        if ((try common.isHtmlElementNamed(node, "ol")) or try isAncestorOfNamed(node, "ol")) all_ul = false;
    }
    if (all_ol) return .ol;
    // Step 7.
    if (all_ul) return .ul;
    // Steps 8-10.
    var some_ol = false;
    var some_ul = false;
    for (node_list.items) |node| {
        if (try isSomeListish(node, "ol")) some_ol = true;
        if (try isSomeListish(node, "ul")) some_ul = true;
    }
    if (some_ol and some_ul) return .mixed;
    if (some_ol) return .mixed_ol;
    if (some_ul) return .mixed_ul;
    // Step 11.
    return .none;
}

// ============================================================================
// Toggling lists
// ============================================================================

/// Sibling criteria "an HTML element with local name `name`", with the
/// default (null) new parent instructions or createElement(`name`).
const NamedContext = struct {
    name: []const u8,
    create: bool,

    pub fn siblingCriteria(self: NamedContext, node: *Instance) anyerror!bool {
        return try common.isHtmlElementNamed(node, self.name);
    }
    pub fn newParent(self: NamedContext, edit: *Edit) anyerror!?*Instance {
        if (!self.create) return null;
        return try edit.createElement(self.name);
    }
};

/// Toggle lists step 11.2.3.3: no sibling criteria, a new li.
const ListItemContext = struct {
    pub fn siblingCriteria(_: ListItemContext, _: *Instance) anyerror!bool {
        return false;
    }
    pub fn newParent(_: ListItemContext, edit: *Edit) anyerror!?*Instance {
        return try edit.createElement("li");
    }
};

/// Toggle lists step 11.5: merge into a sibling list of the type; a run
/// in a simple indentation element after such a list nests in that list's
/// last item list instead of a new list.
const NewListContext = struct {
    name: []const u8,
    first: *Instance,

    pub fn siblingCriteria(self: NewListContext, node: *Instance) anyerror!bool {
        return try common.isHtmlElementNamed(node, self.name);
    }

    pub fn newParent(self: NewListContext, edit: *Edit) anyerror!?*Instance {
        // Step 11.5.1.
        const first_parent = (try common.parent(self.first)) orelse return try edit.createElement(self.name);
        const simple = (try common.isEditable(first_parent)) and try indent.isSimpleIndentationElement(first_parent);
        const before = try common.previousSibling(first_parent);
        const list_before = before != null and (try common.isEditable(before.?)) and try common.isHtmlElementNamed(before.?, self.name);
        if (!simple or !list_before) return try edit.createElement(self.name);
        // Step 11.5.2.
        const list = before.?;
        // Step 11.5.3.
        if (try common.lastChild(list)) |last| try normalizeSublists(edit, last);
        // Step 11.5.4.
        const last = try common.lastChild(list);
        if (last == null or !((try common.isEditable(last.?)) and try common.isHtmlElementNamed(last.?, self.name))) {
            try edit.appendChild(list, try edit.createElement(self.name));
        }
        // Step 11.5.5.
        return try common.lastChild(list);
    }
};

/// The container of an empty line the caret is in, which toggle lists gives
/// a new list inside (see toggleListsAction): a collapsed selection in an
/// empty editing host (nothing to wrap), or in a div - an editable one or
/// the host - whose only child is a br (the node list is that div, or its
/// br).
fn emptyLineContainer(edit: *Edit, node_list: []const *Instance) !?*Instance {
    if (!try edit.rangeCollapsed()) return null;
    const caret = (try edit.rangeStart()) orelse return null;
    if (node_list.len == 0) {
        if (!try common.isEditingHost(caret.node)) return null;
        if ((try common.firstChild(caret.node)) != null) return null;
        return caret.node;
    }
    if (node_list.len != 1) return null;
    // The node list holds the div itself (its block-extended range contains
    // it), or - the host being the div - its br.
    const member = node_list[0];
    const container = if (try common.isHtmlElementNamed(member, "br")) (try common.parent(member)) orelse return null else member;
    if (!try common.isHtmlElementNamed(container, "div")) return null;
    if (!(try common.isEditable(container)) and !try common.isEditingHost(container)) return null;
    // A div with nothing in it at all (`<div>{}</div>`) is an empty line too
    // (lane edit4, A36): the data and Firefox 160 make `<div><ol><li>abc
    // </li></ol></div>` of it with insertOrderedList + "abc" (Gecko keeps a
    // div as the list's container, as for `<div>{}<br></div>`); Chrome 157
    // makes no list at all and Safari 27.2 puts the list before the div -
    // the three differ on where the list goes, so the spec and its data
    // decide (golden rule 2, mechanisms without a majority; integrator's
    // confirmation 2026-11-21 2:11 PM ET). The spec's own steps leave the
    // text outside the item (`<ol><li></li>abc</ol>`), which no browser does.
    if (try common.firstChild(container)) |br| {
        if ((try common.childCount(container)) != 1) return null;
        if (!try common.isHtmlElementNamed(br, "br")) return null;
        if (caret.node != container and caret.node != br) return null;
    } else if (caret.node != container) return null;
    return container;
}

/// An empty `<p>` (no children at all) holding a collapsed selection, which
/// toggle lists replaces with a new list whose one empty item holds the
/// caret (lane edit4, A36): editing/run/insertorderedlist.html and
/// insertunorderedlist.html `<p>{}</p>` + insert*list + "abc" give
/// `<ol><li>abc</li></ol>` in the data and Firefox 160 (FPF, wpt.fyi
/// 2358bd4835). Mechanism by mechanism (golden rule 2): the list replaces
/// the p - Firefox and the spec (set the tag name to li), Chrome 157 keeps
/// the p and makes no list, Safari 27.2 keeps it and puts the list before:
/// no majority, so the spec; the typed text goes into the new item -
/// Firefox and Safari: the majority. The spec's literal steps leave the
/// caret after the item (set the tag name removes the p with the caret in
/// it), so "abc" would land beside the li. A p with its padding br keeps
/// the spec's path (lane edit3, 606c17785).
fn emptyParagraphToReplace(edit: *Edit, node_list: []const *Instance) !?*Instance {
    if (!try edit.rangeCollapsed()) return null;
    const caret = (try edit.rangeStart()) orelse return null;
    if (node_list.len != 1) return null;
    const p = node_list[0];
    if (!try common.isHtmlElementNamed(p, "p")) return null;
    if (!try common.isEditable(p)) return null;
    if ((try common.firstChild(p)) != null) return null;
    if (caret.node != p) return null;
    return p;
}

/// `end` moved before the block whose first position it is, when that block
/// does not hold `start` (see toggleListsAction).
fn endBeforeStartedBlock(start: Point, end: Point) !Point {
    if (end.offset != 0) return end;
    var node = end.node;
    while (true) {
        if (common.isElement(node) and common.isBlockNode(node)) {
            if (try common.isEditingHost(node)) return end;
            if (common.isInclusiveDescendantOf(start.node, node)) return end;
            return try common.pointBefore(node, (try common.parent(node)) orelse return end);
        }
        const p = (try common.parent(node)) orelse return end;
        if ((try common.firstChild(p)) != node) return end;
        node = p;
    }
}

/// Remove and return the first member of `list`.
fn shift(list: *std.ArrayList(*Instance)) *Instance {
    return list.orderedRemove(0);
}

/// "toggle lists" with `tag_name` ("ol" or "ul"), then true (the
/// insertOrderedList / insertUnorderedList action).
pub fn toggleListsAction(edit: *Edit, tag_name: []const u8) !bool {
    // Step 1.
    const mode_disable = (try listState(edit, false)) == (if (std.mem.eql(u8, tag_name, "ol")) ListState.ol else ListState.ul);
    // Step 2.
    const other_tag_name: []const u8 = if (std.mem.eql(u8, tag_name, "ul")) "ol" else "ul";
    // Steps 3-4.
    try normalizeItemsAroundActiveRange(edit);
    // Step 5: the block-extended range (a table cell bounds it, see
    // extendedActiveRange), live through step 6's changes.
    // A selection that ends at the first position of a later block leaves
    // that block out (lane edit4, A26): `<div>[abc</div><div>def</div><div>]
    // ghi</div>` + insertUnorderedList lists abc and def and keeps the ghi
    // div (Chrome 157 and Firefox 160; editing/run/insertunorderedlist.html
    // PPF at wpt.fyi 2358bd4835, Safari lists all three as the spec's
    // block-extend does). Blink's InsertListCommand::DoApply: "When a
    // selection ends at the start of a paragraph ... it would be confusing
    // if [the command] operated on that paragraph" - its end moves to the
    // previous position. Golden rule 2, the majority. The selection itself
    // is not moved.
    const extended = blk: {
        const start = (try edit.rangeStart()) orelse return true;
        var end = (try edit.rangeEnd()) orelse return true;
        if (!try edit.rangeCollapsed()) end = try endBeforeStartedBlock(start, end);
        break :blk try extendedRange(start, end);
    };
    const live = try block.LiveRange.init(edit, extended);
    defer live.release();
    // Step 6: lists of the other type become this type.
    if (!mode_disable) {
        var lists_to_convert: std.ArrayList(*Instance) = .empty;
        defer lists_to_convert.deinit(edit.allocator);
        var walk = try block.ContainedWalk.init(try live.points());
        while (try walk.next()) |node| {
            if ((try common.isEditable(node)) and try common.isHtmlElementNamed(node, other_tag_name)) try lists_to_convert.append(edit.allocator, node);
        }
        for (lists_to_convert.items) |list| {
            // Step 6.1: merge with a neighbouring list of the type.
            if ((try isEditableNamed(try common.previousSibling(list), tag_name)) or (try isEditableNamed(try common.nextSibling(list), tag_name))) {
                var children: std.ArrayList(*Instance) = .empty;
                defer children.deinit(edit.allocator);
                var child = try common.firstChild(list);
                while (child) |c| : (child = try common.nextSibling(c)) try children.append(edit.allocator, c);
                const values = try overrides.recordTheValues(edit, children.items);
                try split_parent.splitParent(edit, children.items);
                _ = try wrap_mod.wrap(edit, children.items, NamedContext{ .name = tag_name, .create = false });
                try overrides.restoreTheValues(edit, values);
            } else {
                // Step 6.2.
                _ = try edit.setTagName(list, tag_name);
            }
        }
    }
    // Steps 7-8.
    var node_list: std.ArrayList(*Instance) = .empty;
    defer node_list.deinit(edit.allocator);
    {
        var walk = try block.ContainedWalk.init(try live.points());
        while (try walk.next()) |node| {
            if (!try common.isEditable(node)) continue;
            if (block.lastIsAncestorOf(node_list.items, node)) continue;
            if (try common.isIndentationElement(node)) continue;
            const kind = (try isList(node)) or (try parentIsList(node)) or try block.isAllowedChildOfName(.{ .node = node }, "li");
            if (!kind) continue;
            try node_list.append(edit.allocator, node);
        }
    }
    // An empty line with nothing to wrap - an empty editing host, or a div
    // holding only its padding br - gets a new list with one empty item at
    // the caret, inside its container: all three browsers turn `{}` and
    // `<div>{}<br></div>` + insertOrderedList + "abc" into `<ol><li>abc</li>
    // </ol>` and `<div><ol><li>abc</li></ol></div>` (editing/run/
    // insertorderedlist.html, insertunorderedlist.html: PPP at wpt.fyi
    // 2358bd4835; Blink InsertListCommand::DoApplyForSingleParagraph puts the
    // list in the empty paragraph, Gecko keeps a div as a container), where
    // the spec's node list is empty or replaces the div. A p keeps the spec's
    // replacement (Firefox and the data; Chrome and Safari nest the list in
    // the p - following them would trade passing subtests).
    if (!mode_disable) {
        if (try emptyLineContainer(edit, node_list.items)) |container| {
            const list = try edit.createElement(tag_name);
            const item = try edit.createElement("li");
            try edit.appendChild(list, item);
            if (try common.firstChild(container)) |br| {
                try edit.appendChild(item, br);
            } else {
                try edit.appendChild(item, try edit.createElement("br"));
            }
            try edit.appendChild(container, list);
            try edit.collapse(item, 0);
            return true;
        }
        if (try emptyParagraphToReplace(edit, node_list.items)) |p| {
            const parent = (try common.parent(p)).?;
            const list = try edit.createElement(tag_name);
            const item = try edit.createElement("li");
            try edit.appendChild(list, item);
            try edit.appendChild(item, try edit.createElement("br"));
            try edit.insertBefore(parent, list, p);
            try edit.removeNode(p);
            try edit.collapse(item, 0);
            return true;
        }
    }
    // Step 9: enabling leaves top-level lists alone.
    if (!mode_disable) {
        var i: usize = 0;
        while (i < node_list.items.len) {
            const node = node_list.items[i];
            if ((try isList(node)) and !try parentIsList(node)) {
                _ = node_list.orderedRemove(i);
            } else i += 1;
        }
    }
    if (mode_disable) {
        // Step 10: every run of siblings leaves its list.
        while (node_list.items.len > 0) {
            // Steps 10.1-10.2.
            var sublist: std.ArrayList(*Instance) = .empty;
            defer sublist.deinit(edit.allocator);
            try sublist.append(edit.allocator, shift(&node_list));
            // Step 10.3.
            if (try common.isHtmlElementNamed(sublist.items[0], tag_name)) {
                try indent.outdent(edit, sublist.items[0]);
                continue;
            }
            // Step 10.4.
            while (node_list.items.len > 0) {
                const candidate = node_list.items[0];
                if ((try common.nextSibling(sublist.items[sublist.items.len - 1])) != candidate) break;
                if (try common.isHtmlElementNamed(candidate, tag_name)) break;
                try sublist.append(edit.allocator, shift(&node_list));
            }
            // Steps 10.5-10.8.
            const values = try overrides.recordTheValues(edit, sublist.items);
            try split_parent.splitParent(edit, sublist.items);
            for (sublist.items) |member| try block.fixDisallowedAncestors(edit, member);
            try overrides.restoreTheValues(edit, values);
        }
        return true;
    }
    // Step 11: every run of siblings becomes items of a list of the type.
    while (node_list.items.len > 0) {
        // Step 11.1.
        var sublist: std.ArrayList(*Instance) = .empty;
        defer sublist.deinit(edit.allocator);
        // The direction of the first block that becomes an item, which the
        // new list takes instead of its items (see below).
        var list_dir: ?[]const u8 = null;
        // Step 11.2.
        while (node_list.items.len > 0 and
            (sublist.items.len == 0 or (try common.nextSibling(sublist.items[sublist.items.len - 1])) == node_list.items[0]))
        {
            const first = node_list.items[0];
            if (try common.isHtmlElementIn(first, &.{ "p", "div" })) {
                // Step 11.2.1.
                _ = shift(&node_list);
                const item = try edit.setTagName(first, "li");
                // A converted block's dir goes to the new list, the first
                // block's for all of them (lane edit4, A25):
                // `<div dir=rtl>a[bc</div><div dir=ltr>de]f</div>` +
                // insertOrderedList gives `<ol dir="rtl"><li>abc</li><li>def
                // </li></ol>` in Firefox 160, and Chrome 157 keeps the first
                // div around the list (`<div dir="rtl"><ol>...</ol></div>`);
                // both are the data's, Safari 27.2 fails all six rows
                // (editing/run/insertorderedlist.html and insertunordered
                // list.html, PPF at wpt.fyi 2358bd4835). Mechanism by
                // mechanism (golden rule 2): the list takes the first line's
                // direction - Chrome and Firefox, the majority; whether the
                // div stays as its container - the two split, so the spec
                // decides, and the spec turns the div into the item
                // (Firefox's shape). The spec's set the tag name would leave
                // each li its own dir.
                if (try common.getAttribute(edit.scratchAllocator(), item, "dir")) |dir| {
                    if (sublist.items.len == 0) list_dir = dir;
                    if (list_dir != null) try common.removeAttribute(item, "dir");
                }
                try sublist.append(edit.allocator, item);
            } else if (try common.isHtmlElementIn(first, &.{ "li", "ol", "ul" })) {
                // Step 11.2.2.
                try sublist.append(edit.allocator, shift(&node_list));
            } else {
                // Step 11.2.3: a run of inline nodes (up to a br) gets an li.
                var nodes_to_wrap: std.ArrayList(*Instance) = .empty;
                defer nodes_to_wrap.deinit(edit.allocator);
                while (node_list.items.len > 0) {
                    if (nodes_to_wrap.items.len > 0) {
                        const last = nodes_to_wrap.items[nodes_to_wrap.items.len - 1];
                        const candidate = node_list.items[0];
                        if ((try common.nextSibling(last)) != candidate) break;
                        if (!common.isInlineNode(candidate)) break;
                        if (!common.isInlineNode(last) or try common.isHtmlElementNamed(last, "br")) break;
                    }
                    try nodes_to_wrap.append(edit.allocator, shift(&node_list));
                }
                if (try wrap_mod.wrap(edit, nodes_to_wrap.items, ListItemContext{})) |item| {
                    try sublist.append(edit.allocator, item);
                } else if (sublist.items.len == 0) {
                    // Nothing to wrap (all invisible): this run is done.
                    break;
                }
            }
        }
        if (sublist.items.len == 0) continue;
        const first_parent = try common.parent(sublist.items[0]);
        // Step 11.3: already in a list of the type, or only lists.
        if (first_parent != null and try common.isHtmlElementNamed(first_parent.?, tag_name)) continue;
        var all_lists = true;
        for (sublist.items) |member| {
            if (!try isList(member)) all_lists = false;
        }
        if (all_lists) continue;
        // Step 11.4: in a list of the other type - split it, rewrap.
        if (first_parent != null and try common.isHtmlElementNamed(first_parent.?, other_tag_name)) {
            const values = try overrides.recordTheValues(edit, sublist.items);
            try split_parent.splitParent(edit, sublist.items);
            _ = try wrap_mod.wrap(edit, sublist.items, NamedContext{ .name = tag_name, .create = true });
            try overrides.restoreTheValues(edit, values);
            continue;
        }
        // Steps 11.5-11.6.
        if (try wrap_mod.wrap(edit, sublist.items, NewListContext{ .name = tag_name, .first = sublist.items[0] })) |result| {
            if (list_dir) |dir| {
                if ((try common.isHtmlElementNamed(result, tag_name)) and !try common.hasAttribute(result, "dir")) {
                    try common.setAttribute(result, "dir", dir);
                    edit.modified = true;
                }
            }
            try block.fixDisallowedAncestors(edit, result);
        }
    }
    return true;
}

/// The list commands' block-extended active range ("the selection's list
/// state" steps 1-2 and toggle lists step 5), with a table cell bounding
/// what a list takes: a boundary point inside a cell - or in a row,
/// between its cells - whose block extension would leave the cell's table
/// stays at that cell's edge. A selection from a table's first row to its
/// last then lists each cell's lines on their own instead of putting the
/// whole table in one list item. Chrome 156 makes four `<td><ol><li>`
/// lists of `<tr data-start=0>...<tr data-end=2>`, and Chrome and Safari 27
/// answer false for queryCommandState afterwards
/// (editing/run/insert-list-items-in-table-cell.html, wpt.fyi 5af3c135c9;
/// Firefox 158 lists the table whole, as the spec does). Blink's
/// InsertListCommand::DoApply iterates the paragraphs of
/// SelectionForParagraphIteration, which snaps "endpoints anchored on
/// table-internal structure into the cell their offset points at, so
/// paragraph iteration runs per-cell instead of wrapping the whole table as
/// one paragraph" and treats a table as a paragraph only when the
/// selection holds it from outside
/// (third_party/blink/renderer/core/editing/commands/
/// editing_commands_utilities.cc, chromium main 2026-10-27). Golden rule 2,
/// no newer spec involved: the browsers split, and the per-cell result is
/// Chrome's and the file's. A selection that holds the table from outside
/// its rows (`{<table>...</table>}`, `<table data-start=0 data-end=1>`) has
/// no boundary cell and still wraps the table whole, as the spec says and
/// all three browsers do.
fn extendedActiveRange(edit: *Edit) !?block.Range {
    const start = (try edit.rangeStart()) orelse return null;
    const end = (try edit.rangeEnd()) orelse return null;
    return try extendedRange(start, end);
}

/// extendedActiveRange over `start` and `end`.
fn extendedRange(start: Point, end: Point) !block.Range {
    var range = try block.blockExtend(start, end);
    if (try boundaryCell(start, .start)) |cell| {
        if (try leavesTableOf(range.start, cell)) range.start = .{ .node = cell, .offset = 0 };
    }
    if (try boundaryCell(end, .end)) |cell| {
        if (try leavesTableOf(range.end, cell)) range.end = .{ .node = cell, .offset = try common.nodeLength(cell) };
    }
    return range;
}

const Side = enum { start, end };

/// The table cell a boundary point is in: an inclusive ancestor td or th
/// of its node, or for a point in a row between two cells, the cell after
/// it (a start) or before it (an end).
fn boundaryCell(point: Point, side: Side) !?*Instance {
    if (try tableCellOf(point.node)) |cell| return cell;
    if (!try common.isHtmlElementNamed(point.node, "tr")) return null;
    const child = switch (side) {
        .start => try common.childAt(point.node, point.offset),
        .end => if (point.offset == 0) null else try common.childAt(point.node, point.offset - 1),
    } orelse return null;
    return if (try common.isHtmlElementIn(child, &.{ "td", "th" })) child else null;
}

/// Whether `point` lies outside the table around `cell`.
fn leavesTableOf(point: Point, cell: *Instance) !bool {
    var ancestor = try common.parent(cell);
    while (ancestor) |a| : (ancestor = try common.parent(a)) {
        if (try common.isHtmlElementNamed(a, "table")) return !common.isInclusiveDescendantOf(point.node, a);
    }
    return false;
}

/// The table cell around `node`, or null.
fn tableCellOf(node: *Instance) !?*Instance {
    var current: ?*Instance = node;
    while (current) |c| : (current = try common.parent(c)) {
        if (try common.isHtmlElementIn(c, &.{ "td", "th" })) return c;
    }
    return null;
}

fn isEditableNamed(node: ?*Instance, name: []const u8) !bool {
    const n = node orelse return false;
    return (try common.isEditable(n)) and try common.isHtmlElementNamed(n, name);
}
