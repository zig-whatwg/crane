//! "Justifying the selection" and the justifyCenter, justifyFull,
//! justifyLeft and justifyRight commands (specs/w3c/execCommand.md): the
//! "alignment value", the action, and the commands' state, value and
//! indeterminacy.
//!
//! The alignment value is the spec's: the resolved text-align of the
//! nearest element that is not display inline or none, start and end mapped
//! through its directionality; no layout is involved.
//!
//! The action follows the browsers (golden rule 2, no newer spec;
//! integrator ruling 2026-10-26, option A). The spec wraps every line in a
//! new `<div style="text-align:X">`; all three browsers in CSS mode, and
//! Chrome and Safari in either mode, instead set `text-align` in the style
//! attribute of the line's own block (`<p>foo[]bar</p>` ->
//! `<p style="text-align:center">foobar</p>`, `<td>b[a]r</td>` ->
//! `<td style="text-align:center">bar</td>`) and make a new block only for a
//! line that has none of its own, named by the default single-line
//! container name (`foo[]bar` -> `<div style="text-align:center">foobar
//! </div>`, or a `<p>` under defaultParagraphSeparator "p"). A line already
//! aligned is left alone, and the alignment of the blocks around it is not
//! touched (`<div align=center><p>[foo]<p>bar</div>` + justifyLeft ->
//! `<div align="center"><p style="text-align:left">foo</p><p>bar</p></div>`).
//! Evidence: editing/run/justify*.html at wpt.fyi 5af3c135c9 (Chrome 156,
//! Firefox 158 align="X" in non-CSS mode, Safari 27). Mechanism: Blink
//! ApplyStyleCommand::ApplyBlockStyle and
//! CompositeEditCommand::MoveParagraphContentsToNewBlockIfNecessary
//! (apply_style_command.cc, composite_edit_command.cc): per paragraph whose
//! style differs, the enclosing block if it holds just that paragraph and is
//! not the editing host, else a new default paragraph element.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const common = @import("common.zig");
const block = @import("block.zig");
const form_associated = @import("../form_associated.zig");

const Edit = common.Edit;
const Point = common.Point;
const Instance = common.Instance;

pub const Alignment = enum {
    center,
    justify,
    left,
    right,

    pub fn name(self: Alignment) []const u8 {
        return @tagName(self);
    }
};

/// The "alignment value" of `node_in`.
pub fn alignmentValue(node_in: *Instance) !Alignment {
    // Step 1: up past non-elements and elements displayed inline or none.
    var current: ?*Instance = node_in;
    var style: ?*const @import("css").computed_style.ComputedStyle = null;
    while (current) |c| : (current = try common.parent(c)) {
        if (!common.isElement(c)) continue;
        const s = (dom.style.computedStyle(c, null) catch null) orelse continue;
        const display = s.display();
        if (display.box == .none) continue;
        if (display.box == .normal and display.outer == .inline_ and display.inner == .flow) continue;
        style = s;
        break;
    }
    // Step 2.
    const element = current orelse return .left;
    const computed = style orelse return .left;
    // Steps 3-6.
    return switch (computed.keyword(.text_align)) {
        .start => if (form_associated.directionality(element) == .rtl) .right else .left,
        .end => if (form_associated.directionality(element) == .rtl) .left else .right,
        // The align-descendants values the presentational hints compute
        // (-webkit-center/-left/-right), as the Editing spec's own notes
        // list them.
        .center, ._webkit_center => .center,
        .justify => .justify,
        .right, ._webkit_right => .right,
        else => .left,
    };
}

/// The visible editable childless nodes the block-extended active range
/// contains (the justify commands' queries); null without an active range.
fn queryLeaves(edit: *Edit, list: *std.ArrayList(*Instance)) !bool {
    const range = (try block.blockExtendActiveRange(edit)) orelse return false;
    try block.visibleEditableLeaves(edit, range, list);
    return true;
}

/// The justify commands' state: at least one leaf, all of `alignment`.
pub fn justifyState(edit: *Edit, alignment: Alignment) !bool {
    var leaves: std.ArrayList(*Instance) = .empty;
    defer leaves.deinit(edit.allocator);
    if (!try queryLeaves(edit, &leaves)) return false;
    if (leaves.items.len == 0) return false;
    for (leaves.items) |leaf| {
        if ((try alignmentValue(leaf)) != alignment) return false;
    }
    return true;
}

/// The justify commands' indeterminacy: some leaf of `alignment`, some not.
pub fn justifyIndeterm(edit: *Edit, alignment: Alignment) !bool {
    var leaves: std.ArrayList(*Instance) = .empty;
    defer leaves.deinit(edit.allocator);
    if (!try queryLeaves(edit, &leaves)) return false;
    var some = false;
    var other = false;
    for (leaves.items) |leaf| {
        if ((try alignmentValue(leaf)) == alignment) some = true else other = true;
    }
    return some and other;
}

/// The justify commands' value: the first leaf's alignment, "left" without
/// one, "" without an active range.
pub fn justifyValue(edit: *Edit) ![]const u8 {
    var leaves: std.ArrayList(*Instance) = .empty;
    defer leaves.deinit(edit.allocator);
    if (!try queryLeaves(edit, &leaves)) return "";
    if (leaves.items.len == 0) return "left";
    return (try alignmentValue(leaves.items[0])).name();
}

// ============================================================================
// Justifying the selection
// ============================================================================

/// Set `alignment` as `element`'s style attribute text-align (replacing a
/// text-align it already declares).
fn setTextAlign(edit: *Edit, element: *Instance, alignment: Alignment) !void {
    if (try common.setInlineStyleProperty(element, "text-align", alignment.name())) edit.modified = true;
}

/// Whether `node` is a block element the line may be aligned through: an
/// editable element that is a block node (not the editing host).
fn isOwnBlock(node: *Instance) !bool {
    return common.isElement(node) and common.isBlockNode(node) and try common.isEditable(node);
}

/// Whether `nodes` (consecutive siblings) are all the visible content of
/// their parent.
fn coversParent(nodes: []const *Instance) !bool {
    const p = (try common.parent(nodes[0])) orelse return false;
    var child = try common.firstChild(p);
    while (child) |c| : (child = try common.nextSibling(c)) {
        if (std.mem.indexOfScalar(*Instance, nodes, c) != null) continue;
        if (try common.isVisible(c)) return false;
    }
    return true;
}

/// "justify the selection" to `alignment`, the browsers' way (module
/// comment); then true.
pub fn justifyTheSelection(edit: *Edit, alignment: Alignment) !bool {
    // Step 1.
    const range = (try block.blockExtendActiveRange(edit)) orelse return true;
    // Steps 5-6 (the spec's steps 2-4 strip align attributes and centers
    // first; no browser does): the outermost editable nodes allowed in a
    // div whose alignment is not `alignment`.
    var node_list: std.ArrayList(*Instance) = .empty;
    defer node_list.deinit(edit.allocator);
    var walk = try block.ContainedWalk.init(range);
    while (try walk.next()) |node| {
        if (block.lastIsAncestorOf(node_list.items, node)) continue;
        if (!try common.isEditable(node)) continue;
        if (!try block.isAllowedChildOfName(.{ .node = node }, "div")) continue;
        if ((try alignmentValue(node)) == alignment) continue;
        try node_list.append(edit.allocator, node);
    }
    // Step 7: each run of consecutive siblings.
    var index: usize = 0;
    while (index < node_list.items.len) {
        const start = index;
        index += 1;
        while (index < node_list.items.len and (try common.nextSibling(node_list.items[index - 1])) == node_list.items[index]) index += 1;
        try alignRun(edit, node_list.items[start..index], alignment);
    }
    return true;
}

/// Align one run of consecutive siblings: through their parent when they are
/// all of an editable block's content; else each block member through its
/// own style, and each line of inline members in a new block.
fn alignRun(edit: *Edit, run_in: []const *Instance, alignment: Alignment) !void {
    // Copy: the steps below move nodes out of the caller's list.
    const run = try edit.allocator.dupe(*Instance, run_in);
    defer edit.allocator.free(run);
    if (try common.parent(run[0])) |p| {
        if ((try isOwnBlock(p)) and try coversParent(run)) {
            var all_inline = true;
            for (run) |member| {
                if (!common.isInlineNode(member)) all_inline = false;
            }
            if (all_inline and !try hasLineBreak(run)) return setTextAlign(edit, p, alignment);
        }
    }
    var i: usize = 0;
    while (i < run.len) {
        const member = run[i];
        if (common.isElement(member) and !common.isInlineNode(member)) {
            try setTextAlign(edit, member, alignment);
            i += 1;
            continue;
        }
        // One line of inline members: up to and including a br.
        const line_start = i;
        while (i < run.len and common.isInlineNode(run[i])) {
            const is_br = try common.isHtmlElementNamed(run[i], "br");
            i += 1;
            if (is_br) break;
        }
        try wrapLine(edit, run[line_start..i], alignment);
    }
}

fn hasLineBreak(nodes: []const *Instance) !bool {
    for (nodes) |node| {
        if (try common.isHtmlElementNamed(node, "br")) return true;
    }
    return false;
}

/// Wrap one line of inline siblings in a new default single-line container
/// with `alignment` (its trailing br goes: the new block ends the line).
fn wrapLine(edit: *Edit, line: []const *Instance, alignment: Alignment) !void {
    if (line.len == 0) return;
    var nodes = line;
    const last = nodes[nodes.len - 1];
    const drop_br = nodes.len > 1 and try common.isHtmlElementNamed(last, "br");
    if (drop_br) nodes = nodes[0 .. nodes.len - 1];
    const p = (try common.parent(nodes[0])) orelse return;
    const name = try block.defaultSingleLineContainerName(edit);
    if (!try common.isAllowedChild(.{ .name = name }, p)) return;
    const container = try edit.createElement(name);
    try edit.insertBefore(p, container, nodes[0]);
    for (nodes) |node| try edit.movePreservingRanges(node, container, try common.childCount(container));
    try setTextAlign(edit, container, alignment);
    if (drop_br) try edit.removeNode(last);
}
