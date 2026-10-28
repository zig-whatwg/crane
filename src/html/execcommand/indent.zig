//! "Indenting and outdenting" and the indent and outdent commands
//! (specs/w3c/execCommand.md), step by step, plus the delete command's step
//! 10 (Backspace at the start of an indentation element outdents it).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const common = @import("common.zig");
const block = @import("block.zig");
const lists = @import("lists.zig");
const split_parent = @import("split_parent.zig");
const overrides = @import("overrides.zig");
const wrap_mod = @import("wrap.zig");

const Edit = common.Edit;
const Point = common.Point;
const Instance = common.Instance;
const DOMString = runtime.DOMString;

fn isList(node: *Instance) !bool {
    return try common.isHtmlElementIn(node, &.{ "ol", "ul" });
}

/// Whether a CSS property name is margin, border or padding or one of
/// their subproperties (a vendor prefix allowed), as the reference
/// implementation tests the longhands a style attribute sets.
fn isBoxProperty(name: []const u8) bool {
    var rest = name;
    if (rest.len > 0 and rest[0] == '-') {
        const dash = std.mem.indexOfScalarPos(u8, rest, 1, '-') orelse return false;
        rest = rest[dash + 1 ..];
    }
    return std.mem.startsWith(u8, rest, "margin") or std.mem.startsWith(u8, rest, "border") or std.mem.startsWith(u8, rest, "padding");
}

/// "simple indentation element": an indentation element whose only
/// attributes are a style attribute setting nothing but margin, border and
/// padding (and their subproperties) and/or a dir attribute.
pub fn isSimpleIndentationElement(node: *Instance) !bool {
    if (!try common.isIndentationElement(node)) return false;
    const allocator = node.ctx.allocator;
    const attributes = try interfaces.Element.get_attributes(node);
    const count = try interfaces.NamedNodeMap.get_length(attributes);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const attr = (try interfaces.NamedNodeMap.call_item(attributes, i)) orelse continue;
        var namespace = try interfaces.Attr.get_namespaceURI(attr);
        defer if (namespace) |*n| n.deinit(allocator);
        if (namespace != null and !std.mem.eql(u8, namespace.?.asSlice(), common.html_namespace)) return false;
        var name = try interfaces.Attr.get_name(attr);
        defer name.deinit(allocator);
        if (!std.mem.eql(u8, name.asSlice(), "style") and !std.mem.eql(u8, name.asSlice(), "dir")) return false;
    }
    const declaration = try interfaces.HTMLElement.get_style(node);
    const length = try interfaces.CSSStyleDeclaration.get_length(declaration);
    var j: u32 = 0;
    while (j < length) : (j += 1) {
        var property = try interfaces.CSSStyleDeclaration.call_item(declaration, j);
        defer property.deinit(allocator);
        if (!isBoxProperty(property.asSlice())) return false;
    }
    return true;
}

// ============================================================================
// indent
// ============================================================================

/// Indent step 3.2's sibling criteria and new parent: a list of the same
/// type.
const SameListContext = struct {
    tag: []const u8,
    pub fn siblingCriteria(self: SameListContext, node: *Instance) anyerror!bool {
        return try common.isHtmlElementNamed(node, self.tag);
    }
    pub fn newParent(self: SameListContext, edit: *Edit) anyerror!?*Instance {
        return try edit.createElement(self.tag);
    }
};

/// Indent step 4: merge into a simple indentation element, else a new
/// blockquote.
const BlockquoteContext = struct {
    pub fn siblingCriteria(_: BlockquoteContext, node: *Instance) anyerror!bool {
        return try isSimpleIndentationElement(node);
    }
    pub fn newParent(_: BlockquoteContext, edit: *Edit) anyerror!?*Instance {
        return try edit.createElement("blockquote");
    }
};

/// "indent" a list of consecutive siblings.
pub fn indentNodes(edit: *Edit, node_list: []const *Instance) !void {
    // Step 1.
    if (node_list.len == 0) return;
    // Step 2.
    const first = node_list[0];
    // Step 3: items of a list nest in a list of their parent's type.
    if (try common.parent(first)) |p| {
        if (try isList(p)) {
            var buffer: [8]u8 = undefined;
            const tag = (try common.localNameInto(p, &buffer)) orelse return;
            _ = try wrap_mod.wrap(edit, node_list, SameListContext{ .tag = tag });
            return;
        }
    }
    // Step 4.
    const new_parent = (try wrap_mod.wrap(edit, node_list, BlockquoteContext{})) orelse return;
    // Step 5.
    try block.fixDisallowedAncestors(edit, new_parent);
}

// ============================================================================
// outdent
// ============================================================================

/// Unset one CSS property set by `element`'s style attribute.
fn unsetStyleProperty(edit: *Edit, element: *Instance, name: []const u8) !void {
    if (!try common.isHtmlElement(element)) return;
    const declaration = try interfaces.HTMLElement.get_style(element);
    var removed = try interfaces.CSSStyleDeclaration.call_removeProperty(declaration, DOMString.initInterned(name));
    defer removed.deinit(element.ctx.allocator);
    if (removed.asSlice().len > 0) edit.modified = true;
}

/// Remove an attribute when it is there.
fn unsetAttribute(edit: *Edit, element: *Instance, name: []const u8) !void {
    if (!try common.hasAttribute(element, name)) return;
    try common.removeAttribute(element, name);
    edit.modified = true;
}

/// Whether `node` is an editable Element that is neither a simple
/// indentation element (or, `any_indentation`, any indentation element)
/// nor an ol nor a ul (outdent steps 6 and 7.3).
fn isPassThroughAncestor(node: *Instance, any_indentation: bool) !bool {
    if (!common.isElement(node)) return false;
    if (!try common.isEditable(node)) return false;
    if (try isList(node)) return false;
    if (any_indentation) return !try common.isIndentationElement(node);
    return !try isSimpleIndentationElement(node);
}

/// "outdent" `node`.
pub fn outdent(edit: *Edit, node: *Instance) anyerror!void {
    // Step 1.
    if (!try common.isEditable(node)) return;
    // Step 2.
    if (try isSimpleIndentationElement(node)) {
        try split_parent.removePreservingDescendants(edit, node);
        return;
    }
    // Step 3.
    if (try common.isIndentationElement(node)) {
        // Step 3.1.
        try unsetAttribute(edit, node, "dir");
        // Step 3.2: margin, padding and border, then a style attribute left
        // empty goes too (the reference implementation's cleanup).
        try unsetStyleProperty(edit, node, "margin");
        try unsetStyleProperty(edit, node, "padding");
        try unsetStyleProperty(edit, node, "border");
        if (try interfaces.Element.call_getAttribute(node, DOMString.initInterned("style"))) |style| {
            var owned = style;
            defer owned.deinit(node.ctx.allocator);
            if (std.mem.trim(u8, owned.asSlice(), " ").len == 0) try unsetAttribute(edit, node, "style");
        }
        // Step 3.3.
        _ = try edit.setTagName(node, "div");
        // Step 3.4.
        return;
    }
    // Steps 4-6: look for a simple indentation element above.
    var ancestor_list: std.ArrayList(*Instance) = .empty;
    defer ancestor_list.deinit(edit.allocator);
    var current_ancestor = try common.parent(node);
    while (current_ancestor) |c| {
        if (!try isPassThroughAncestor(c, false)) break;
        try ancestor_list.append(edit.allocator, c);
        current_ancestor = try common.parent(c);
    }
    // Step 7: failing that, any indentation element.
    const found_simple = if (current_ancestor) |c| (try common.isEditable(c)) and try isSimpleIndentationElement(c) else false;
    if (!found_simple) {
        current_ancestor = try common.parent(node);
        ancestor_list.clearRetainingCapacity();
        while (current_ancestor) |c| {
            if (!try isPassThroughAncestor(c, true)) break;
            try ancestor_list.append(edit.allocator, c);
            current_ancestor = try common.parent(c);
        }
    }
    const at_indentation = if (current_ancestor) |c| (try common.isEditable(c)) and try common.isIndentationElement(c) else false;
    // Step 8: a list not inside an indentation element loses its list.
    if ((try isList(node)) and !at_indentation) {
        // Step 8.1.
        try unsetAttribute(edit, node, "reversed");
        try unsetAttribute(edit, node, "start");
        try unsetAttribute(edit, node, "type");
        // Step 8.2.
        var children: std.ArrayList(*Instance) = .empty;
        defer children.deinit(edit.allocator);
        var child = try common.firstChild(node);
        while (child) |c| : (child = try common.nextSibling(c)) try children.append(edit.allocator, c);
        // Steps 8.3-8.4.
        const attributes = try interfaces.Element.get_attributes(node);
        const has_attributes = (try interfaces.NamedNodeMap.get_length(attributes)) > 0;
        const parent_is_list = if (try common.parent(node)) |p| try isList(p) else false;
        if (has_attributes and !parent_is_list) {
            _ = try edit.setTagName(node, "div");
        } else {
            const values = try overrides.recordTheValues(edit, children.items);
            try split_parent.removePreservingDescendants(edit, node);
            try overrides.restoreTheValues(edit, values);
        }
        // Step 8.5.
        for (children.items) |c| try block.fixDisallowedAncestors(edit, c);
        // Step 8.6.
        return;
    }
    // Step 9.
    if (!at_indentation) return;
    // Step 10.
    try ancestor_list.append(edit.allocator, current_ancestor.?);
    // Step 11.
    const original_ancestor = current_ancestor.?;
    // Step 12: re-indent everything beside the path down to node.
    while (ancestor_list.items.len > 0) {
        // Steps 12.1-12.2.
        const ancestor = ancestor_list.pop().?;
        // Step 12.3.
        const target = if ((try common.parent(node)) == ancestor) node else (if (ancestor_list.items.len > 0) ancestor_list.items[ancestor_list.items.len - 1] else node);
        // Step 12.4.
        if (common.isInlineNode(target) and !try common.isHtmlElementNamed(target, "br")) {
            if (try common.nextSibling(target)) |next| {
                if (try common.isHtmlElementNamed(next, "br")) try edit.removeNode(next);
            }
        }
        // Step 12.5.
        var preceding: std.ArrayList(*Instance) = .empty;
        defer preceding.deinit(edit.allocator);
        var following: std.ArrayList(*Instance) = .empty;
        defer following.deinit(edit.allocator);
        var child = try common.firstChild(ancestor);
        var seen_target = false;
        while (child) |c| : (child = try common.nextSibling(c)) {
            if (c == target) {
                seen_target = true;
                continue;
            }
            if (seen_target) try following.append(edit.allocator, c) else try preceding.append(edit.allocator, c);
        }
        // Steps 12.6-12.7.
        try indentNodes(edit, preceding.items);
        try indentNodes(edit, following.items);
    }
    // Step 13.
    try outdent(edit, original_ancestor);
}

// ============================================================================
// The indent and outdent commands
// ============================================================================

/// Remove and return the first member of `list`.
fn shift(list: *std.ArrayList(*Instance)) *Instance {
    return list.orderedRemove(0);
}

/// The indent command's action.
pub fn indentAction(edit: *Edit) !bool {
    // Steps 1-2.
    try lists.normalizeItemsAroundActiveRange(edit);
    // Step 3.
    const range = (try block.blockExtendActiveRange(edit)) orelse return true;
    // Steps 4-5.
    var node_list: std.ArrayList(*Instance) = .empty;
    defer node_list.deinit(edit.allocator);
    var walk = try block.ContainedWalk.init(range);
    while (try walk.next()) |node| {
        if (!try common.isEditable(node)) continue;
        if (block.lastIsAncestorOf(node_list.items, node)) continue;
        if (!(try block.isAllowedChildOfName(.{ .node = node }, "div")) and !try block.isAllowedChildOfName(.{ .node = node }, "ol")) continue;
        try node_list.append(edit.allocator, node);
    }
    // Step 6: an item indented under a previous item whose sublists are
    // normalized.
    for (node_list.items) |member| {
        if (!try common.isVisible(member)) continue;
        if (try common.isHtmlElementNamed(member, "li")) {
            const p = try common.parent(member);
            if (p != null and try isList(p.?)) {
                var sibling = try common.previousSibling(member);
                while (sibling) |s| {
                    if (!try common.isInvisible(s)) break;
                    sibling = try common.previousSibling(s);
                }
                if (sibling) |s| {
                    if (try common.isHtmlElementNamed(s, "li")) try lists.normalizeSublists(edit, s);
                }
            }
        }
        break;
    }
    // Step 7.
    while (node_list.items.len > 0) {
        var sublist: std.ArrayList(*Instance) = .empty;
        defer sublist.deinit(edit.allocator);
        try sublist.append(edit.allocator, shift(&node_list));
        while (node_list.items.len > 0 and (try common.nextSibling(sublist.items[sublist.items.len - 1])) == node_list.items[0]) {
            try sublist.append(edit.allocator, shift(&node_list));
        }
        try indentNodes(edit, sublist.items);
    }
    // Step 8.
    return true;
}

/// The outdent command's action.
pub fn outdentAction(edit: *Edit) !bool {
    // Steps 1-2.
    try lists.normalizeItemsAroundActiveRange(edit);
    // Step 3.
    const range = (try block.blockExtendActiveRange(edit)) orelse return true;
    // Steps 4-5.
    var node_list: std.ArrayList(*Instance) = .empty;
    defer node_list.deinit(edit.allocator);
    var walk = try block.ContainedWalk.init(range);
    while (try walk.next()) |node| {
        if (block.lastIsAncestorOf(node_list.items, node)) continue;
        if (!try common.isEditable(node)) continue;
        const kind = !(try block.hasEditableDescendants(node)) or (try isList(node)) or
            ((try common.isHtmlElementNamed(node, "li")) and try parentIsList(node));
        if (!kind) continue;
        try node_list.append(edit.allocator, node);
    }
    // Step 6.
    while (node_list.items.len > 0) {
        // Step 6.1.
        while (node_list.items.len > 0) {
            const first = node_list.items[0];
            if (!(try isList(first)) and try parentIsList(first)) break;
            try outdent(edit, first);
            _ = shift(&node_list);
        }
        // Step 6.2.
        if (node_list.items.len == 0) break;
        // Steps 6.3-6.5.
        var sublist: std.ArrayList(*Instance) = .empty;
        defer sublist.deinit(edit.allocator);
        try sublist.append(edit.allocator, shift(&node_list));
        while (node_list.items.len > 0) {
            const candidate = node_list.items[0];
            if ((try common.nextSibling(sublist.items[sublist.items.len - 1])) != candidate) break;
            if (try isList(candidate)) break;
            try sublist.append(edit.allocator, shift(&node_list));
        }
        // Steps 6.6-6.9.
        const values = try overrides.recordTheValues(edit, sublist.items);
        try split_parent.splitParent(edit, sublist.items);
        for (sublist.items) |member| try block.fixDisallowedAncestors(edit, member);
        try overrides.restoreTheValues(edit, values);
    }
    // Step 7.
    return true;
}

fn parentIsList(node: *Instance) !bool {
    const p = (try common.parent(node)) orelse return false;
    return try isList(p);
}

/// The delete command's step 10, at the start of an indentation element:
/// block-extend the collapsed range at (node, 0), and outdent each editable
/// node in it that has no editable descendants.
pub fn outdentAtIndentationElement(edit: *Edit, node: *Instance) !void {
    // Step 10.1.
    const at: Point = .{ .node = node, .offset = 0 };
    const range = try block.blockExtend(at, at);
    // Steps 10.2-10.3.
    var node_list: std.ArrayList(*Instance) = .empty;
    defer node_list.deinit(edit.allocator);
    var walk = try block.ContainedWalk.init(range);
    while (try walk.next()) |current| {
        if (block.lastIsAncestorOf(node_list.items, current)) continue;
        if (!try common.isEditable(current)) continue;
        if (try block.hasEditableDescendants(current)) continue;
        try node_list.append(edit.allocator, current);
    }
    // Step 10.4.
    for (node_list.items) |member| try outdent(edit, member);
}

test "box properties for a simple indentation element" {
    try std.testing.expect(isBoxProperty("margin-left"));
    try std.testing.expect(isBoxProperty("border-top-width"));
    try std.testing.expect(isBoxProperty("-webkit-margin-start"));
    try std.testing.expect(!isBoxProperty("color"));
    try std.testing.expect(!isBoxProperty("text-align"));
}
