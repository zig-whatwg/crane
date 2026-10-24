//! "Splitting a node list's parent" (specs/w3c/execCommand.md): split the
//! parent of a list of consecutive siblings, and remove a node preserving
//! its descendants.

const std = @import("std");
const common = @import("common.zig");

const Edit = common.Edit;
const Instance = common.Instance;

fn contains(list: []const *Instance, node: *Instance) bool {
    for (list) |member| if (member == node) return true;
    return false;
}

/// "split the parent" of `node_list`, consecutive siblings in tree order.
pub fn splitParent(edit: *Edit, node_list: []const *Instance) !void {
    if (node_list.len == 0) return;
    const first = node_list[0];
    const last = node_list[node_list.len - 1];
    // Step 1.
    const original_parent = (try common.parent(first)) orelse return;
    // Step 2.
    if (!try common.isEditable(original_parent)) return;
    const grandparent = (try common.parent(original_parent)) orelse return;
    const first_in_list = if (try common.firstChild(original_parent)) |c| contains(node_list, c) else false;
    // Step 3.
    if (first_in_list) try edit.removeExtraneousLineBreaksBefore(original_parent);
    // Step 4.
    const follows_line_break = first_in_list and try common.followsLineBreak(original_parent);
    // Step 5.
    const last_in_list = if (try common.lastChild(original_parent)) |c| contains(node_list, c) else false;
    const precedes_line_break = last_in_list and try common.precedesLineBreak(original_parent);
    // Step 6: the list is the parent's tail - move it after the parent.
    if (!first_in_list and last_in_list) {
        // Step 6.1: in reverse order, each immediately after original parent.
        var i = node_list.len;
        while (i > 0) {
            i -= 1;
            try edit.movePreservingRanges(node_list[i], grandparent, 1 + try common.indexOf(original_parent));
        }
        // Step 6.2.
        if (precedes_line_break and !try common.precedesLineBreak(last)) {
            const br = try edit.createElement("br");
            try edit.insertBefore(grandparent, br, try common.nextSibling(last));
        }
        // Step 6.3.
        try edit.removeExtraneousLineBreaksAtTheEndOf(original_parent);
        // Step 6.4.
        return;
    }
    // Step 7: preceding siblings go into a clone of the parent.
    if (!first_in_list) {
        // Step 7.1.
        const cloned_parent = try common.cloneNode(original_parent, false);
        // Step 7.2.
        if (try common.hasAttribute(original_parent, "id")) {
            try common.removeAttribute(original_parent, "id");
            edit.modified = true;
        }
        // Step 7.3.
        try edit.insertBefore(grandparent, cloned_parent, original_parent);
        // Step 7.4.
        while ((try common.previousSibling(first)) != null) {
            const child = (try common.firstChild(original_parent)) orelse break;
            try edit.movePreservingRanges(child, cloned_parent, try common.childCount(cloned_parent));
        }
    }
    // Step 8: the list goes before original parent.
    for (node_list) |node| {
        try edit.movePreservingRanges(node, grandparent, try common.indexOf(original_parent));
    }
    // Step 9.
    if (follows_line_break and !try common.followsLineBreak(first)) {
        const br = try edit.createElement("br");
        try edit.insertBefore(grandparent, br, first);
    }
    // Step 10.
    if (common.isInlineNode(last) and !(try common.isHtmlElementNamed(last, "br"))) {
        if (try common.firstChild(original_parent)) |first_remaining| {
            if ((try common.isHtmlElementNamed(first_remaining, "br")) and !common.isInlineNode(original_parent)) {
                try edit.removeNode(first_remaining);
            }
        }
    }
    // Step 11.
    if (!try common.hasChildren(original_parent)) {
        // Step 11.1.
        try edit.removeNode(original_parent);
        // Step 11.2.
        if (precedes_line_break and !try common.precedesLineBreak(last)) {
            const br = try edit.createElement("br");
            try edit.insertBefore(grandparent, br, try common.nextSibling(last));
        }
    } else {
        // Step 12.
        try edit.removeExtraneousLineBreaksBefore(original_parent);
    }
    // Step 13.
    if ((try common.nextSibling(last)) == null) {
        if (try common.parent(last)) |p| try edit.removeExtraneousLineBreaksAtTheEndOf(p);
    }
}

/// Remove `node` "preserving its descendants": split the parent of its
/// children, or remove it when it has none.
pub fn removePreservingDescendants(edit: *Edit, node: *Instance) !void {
    if (!try common.hasChildren(node)) return edit.removeNode(node);
    var children: std.ArrayList(*Instance) = .empty;
    defer children.deinit(edit.allocator);
    var child = try common.firstChild(node);
    while (child) |c| : (child = try common.nextSibling(c)) try children.append(edit.allocator, c);
    try splitParent(edit, children.items);
}
