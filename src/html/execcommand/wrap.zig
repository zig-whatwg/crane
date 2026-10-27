//! The Editing spec's "wrap" a list of consecutive sibling nodes
//! (specs/w3c/execCommand.md, "Wrapping a list of nodes"), shared by the
//! inline formatting commands (force the value) and the block commands
//! (indent, formatBlock, the list toggles, insertParagraph).
//!
//! ONE copy for both editing lanes (integrator ruling 2026-10-26, editing3
//! Q1): lane editing4 carries this file byte-identically, and any change to
//! it goes through the integrator.
//!
//! The DOM is read and changed through the generated interfaces and the
//! common definitions (common.zig), never an impl.

const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const common = @import("common.zig");

const Edit = common.Edit;
const Instance = common.Instance;

/// The spec's defaults: "If not provided, sibling criteria returns false
/// and new parent instructions returns null."
pub const NoCriteria = struct {
    pub fn siblingCriteria(self: NoCriteria, node: *Instance) anyerror!bool {
        _ = self;
        _ = node;
        return false;
    }

    pub fn newParent(self: NoCriteria, edit: *Edit) anyerror!?*Instance {
        _ = self;
        _ = edit;
        return null;
    }
};

pub const no_criteria = NoCriteria{};

/// "wrap" `node_list_in` (consecutive siblings, at least one): the new
/// parent, or null when the algorithm aborts. `context` (a value or a
/// pointer) supplies the two algorithms the spec passes in:
///
///     fn siblingCriteria(self, node: *Instance) anyerror!bool
///     fn newParent(self, edit: *Edit) anyerror!?*Instance
///
/// `no_criteria` is the spec's default for both.
pub fn wrap(edit: *Edit, node_list_in: []const *Instance, context: anytype) !?*Instance {
    if (node_list_in.len == 0) return null;
    var node_list: std.ArrayList(*Instance) = .empty;
    defer node_list.deinit(edit.allocator);
    try node_list.appendSlice(edit.allocator, node_list_in);

    // Step 1: "If every member of node list is invisible, and none is a br,
    // return null and abort these steps." A br counts as visible here:
    // wrapping one can turn an extraneous line break into a meaningful one.
    var any_visible_or_br = false;
    for (node_list.items) |node| {
        if ((try common.isHtmlElementNamed(node, "br")) or !try common.isInvisible(node)) {
            any_visible_or_br = true;
            break;
        }
    }
    if (!any_visible_or_br) return null;

    // Step 2: "If node list's first member's parent is null, return null
    // and abort these steps."
    if ((try common.parent(node_list.items[0])) == null) return null;

    // Step 3: a trailing br goes with its line: "If node list's last member
    // is an inline node that's not a br, and node list's last member's
    // nextSibling is a br, append that br to node list."
    {
        const last = node_list.items[node_list.items.len - 1];
        if (common.isInlineNode(last) and !try common.isHtmlElementNamed(last, "br")) {
            if (try common.nextSibling(last)) |next| {
                if (try common.isHtmlElementNamed(next, "br")) try node_list.append(edit.allocator, next);
            }
        }
    }

    // Step 4: "While node list's first member's previousSibling is
    // invisible, prepend it to node list."
    while (try common.previousSibling(node_list.items[0])) |previous| {
        if (!try common.isInvisible(previous)) break;
        try node_list.insert(edit.allocator, 0, previous);
    }

    // Step 5: "While node list's last member's nextSibling is invisible,
    // append it to node list."
    while (try common.nextSibling(node_list.items[node_list.items.len - 1])) |next| {
        if (!try common.isInvisible(next)) break;
        try node_list.append(edit.allocator, next);
    }

    const first = node_list.items[0];
    const last = node_list.items[node_list.items.len - 1];

    // Steps 6-8: an editable sibling the criteria accept, else the new
    // parent instructions' node.
    var new_parent: ?*Instance = null;
    if (try common.previousSibling(first)) |previous| {
        if ((try common.isEditable(previous)) and try context.siblingCriteria(previous)) new_parent = previous;
    }
    if (new_parent == null) {
        if (try common.nextSibling(last)) |next| {
            if ((try common.isEditable(next)) and try context.siblingCriteria(next)) new_parent = next;
        }
    }
    if (new_parent == null) new_parent = try context.newParent(edit);

    // Step 9: "If new parent is null, abort these steps and return null."
    const parent_node = new_parent orelse return null;

    // Step 10: "If new parent's parent is null:"
    if ((try common.parent(parent_node)) == null) {
        // Step 10.1: "Insert new parent into the parent of the first member
        // of node list immediately before the first member of node list."
        const first_parent = (try common.parent(first)) orelse return null;
        try edit.insertBefore(first_parent, parent_node, first);
        // Step 10.2: "If any range has a boundary point with node equal to
        // the parent of new parent and offset equal to the index of new
        // parent, add one to that boundary point's offset" - so the points
        // around the wrapped nodes end up inside the wrapper once they move
        // preserving ranges.
        sweepBoundaryPointsPast(edit, first_parent, try common.indexOf(parent_node));
    }

    // Step 11: "Let original parent be the parent of the first member of
    // node list."
    const original_parent = try common.parent(first);

    // Step 12: "If new parent is before the first member of node list in
    // tree order:"
    if (try isBeforeInTreeOrder(parent_node, first)) {
        // Step 12.1: a br between the new parent's last visible inline
        // child and the first visible inline member, when the new parent
        // is not inline and its last child is not already a br.
        if (common.isBlockNode(parent_node)) {
            const last_visible_child = try lastVisibleChild(parent_node);
            const first_visible_member = try firstVisible(node_list.items);
            const last_child = try common.lastChild(parent_node);
            if (last_visible_child != null and first_visible_member != null and
                common.isInlineNode(last_visible_child.?) and common.isInlineNode(first_visible_member.?) and
                !(last_child != null and try common.isHtmlElementNamed(last_child.?, "br")))
            {
                const br = try edit.createElement("br");
                try edit.appendChild(parent_node, br);
            }
        }
        // Step 12.2: "For each node in node list, append node as the last
        // child of new parent, preserving ranges."
        for (node_list.items) |node| {
            try edit.movePreservingRanges(node, parent_node, try common.childCount(parent_node));
        }
    } else {
        // Step 13.1: the mirror image, a br as the new parent's first child.
        if (common.isBlockNode(parent_node)) {
            const first_visible_child = try firstVisibleChild(parent_node);
            const last_visible_member = try lastVisible(node_list.items);
            if (first_visible_child != null and last_visible_member != null and
                common.isInlineNode(first_visible_child.?) and common.isInlineNode(last_visible_member.?) and
                !try common.isHtmlElementNamed(last, "br"))
            {
                const br = try edit.createElement("br");
                try edit.insertBefore(parent_node, br, try common.firstChild(parent_node));
            }
        }
        // Step 13.2: "For each node in node list, in reverse order, insert
        // node as the first child of new parent, preserving ranges."
        var i = node_list.items.len;
        while (i > 0) {
            i -= 1;
            try edit.movePreservingRanges(node_list.items[i], parent_node, 0);
        }
    }

    // Step 14: "If original parent is editable and has no children, remove
    // it from its parent."
    if (original_parent) |op| {
        if ((try common.isEditable(op)) and !try common.hasChildren(op)) try edit.removeNode(op);
    }

    // Step 15: "If new parent's nextSibling is editable and running sibling
    // criteria on it returns true:" - both siblings matched; merge them.
    if (try common.nextSibling(parent_node)) |next| {
        if ((try common.isEditable(next)) and try context.siblingCriteria(next)) {
            // Step 15.1: a br between them when the new parent is not
            // inline but its last child and the sibling's first child are,
            // and its last child is not a br.
            if (common.isBlockNode(parent_node)) {
                const last_child = try common.lastChild(parent_node);
                const next_first = try common.firstChild(next);
                if (last_child != null and next_first != null and
                    common.isInlineNode(last_child.?) and common.isInlineNode(next_first.?) and
                    !try common.isHtmlElementNamed(last_child.?, "br"))
                {
                    const br = try edit.createElement("br");
                    try edit.appendChild(parent_node, br);
                }
            }
            // Step 15.2: "While new parent's nextSibling has children,
            // append its first child as the last child of new parent,
            // preserving ranges."
            while (try common.firstChild(next)) |child| {
                try edit.movePreservingRanges(child, parent_node, try common.childCount(parent_node));
            }
            // Step 15.3: "Remove new parent's nextSibling from its parent."
            try edit.removeNode(next);
        }
    }

    // Step 16: "Remove extraneous line breaks from new parent."
    try edit.removeExtraneousLineBreaksFrom(parent_node);

    // Step 17: "Return new parent."
    return parent_node;
}

/// Whether `a` is before `b` in tree order (an ancestor is before its
/// descendants).
fn isBeforeInTreeOrder(a: *Instance, b: *Instance) !bool {
    if (a == b) return false;
    const position = try interfaces.Node.call_compareDocumentPosition(a, b);
    return position & interfaces.Node.get_DOCUMENT_POSITION_FOLLOWING() != 0;
}

fn lastVisibleChild(node: *Instance) !?*Instance {
    var child = try common.lastChild(node);
    while (child) |c| : (child = try common.previousSibling(c)) {
        if (try common.isVisible(c)) return c;
    }
    return null;
}

fn firstVisibleChild(node: *Instance) !?*Instance {
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (try common.isVisible(c)) return c;
    }
    return null;
}

fn firstVisible(nodes: []const *Instance) !?*Instance {
    for (nodes) |node| if (try common.isVisible(node)) return node;
    return null;
}

fn lastVisible(nodes: []const *Instance) !?*Instance {
    var i = nodes.len;
    while (i > 0) {
        i -= 1;
        if (try common.isVisible(nodes[i])) return nodes[i];
    }
    return null;
}

/// Step 10.2 over every live range of the document: a boundary point
/// (`container`, `offset`) moves to (`container`, `offset` + 1).
///
/// Every write happens inside the live list's walk, to the entry the walk
/// is on, and no range pointer is kept outside it. The write is the Range's
/// own boundary step (dom.range_boundaries set_start_offset /
/// set_end_offset, Range.zig setStartOffset/setEndOffset): it tells a
/// Selection the range belongs to (notifySelection, which may schedule a
/// selectionchange) - an engine call that can allocate and so start a V8
/// collection, whose pending second passes tear down ranges script let go
/// of, each removing itself from this list. The walk survives that: it reads
/// one entry at a time through a cursor, and the list's `remove` moves the
/// cursor of every walk in progress past a removed entry (Gecko's
/// nsTObserverArray design), so every entry still listed is visited once and
/// none freed is read (src/dom/live_range_list.zig; lane rangeuaf). A copy
/// of the entries, as this sweep first made, would hold ranges such a
/// teardown frees.
fn sweepBoundaryPointsPast(edit: *Edit, container: *Instance, offset: u32) void {
    const ranges = dom.document_internals.liveRanges(edit.document) orelse return;
    const live = dom.range_boundaries.liveRange() orelse return;
    var walk: dom.document_internals.LiveObjects.Walk = undefined;
    ranges.beginWalk(&walk);
    defer ranges.endWalk(&walk);
    while (walk.nextEntry()) |range| {
        const points = live.points(range) orelse continue;
        const start_hit = points.start_container == container and points.start_offset == offset;
        const end_hit = points.end_container == container and points.end_offset == offset;
        if (start_hit) live.set_start_offset(range, offset + 1);
        if (end_hit) live.set_end_offset(range, offset + 1);
    }
}
