//! Selection's editable focus target, independent of caret geometry.
//! Blink FrameSelection::SetFocusedNodeIfNeeded at
//! 8d5ba1795f0c50b90072399d0403389df6eebbd6 focuses the canonical
//! position's root editable element, rather than the raw boundary container.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const editing = @import("execcommand/common.zig");
const focus = @import("focus.zig");
const Instance = runtime.Instance;

fn parent(node: *Instance) ?*Instance {
    return interfaces.Node.get_parentNode(node) catch null;
}

fn rootEditable(node: *Instance) ?*Instance {
    var root = (editing.editingHostOf(node) catch null) orelse return null;
    // Nested contenteditable=true does not divide an already editable
    // region; a contenteditable=false ancestor does.
    while (parent(root)) |p| {
        root = (editing.editingHostOf(p) catch null) orelse break;
    }
    return root;
}

const Candidate = enum { absent, editable, noneditable_block };

fn candidate(node: *Instance) Candidate {
    const kind = interfaces.Node.get_nodeType(node) catch return .absent;
    if (kind == interfaces.Node.get_COMMENT_NODE()) return .absent;
    if (kind == interfaces.Node.get_TEXT_NODE()) {
        if ((interfaces.CharacterData.get_length(node) catch 0) == 0) return .absent;
        return if (editing.isWhitespaceNode(node) catch false) .absent else .editable;
    }
    if (kind != interfaces.Node.get_ELEMENT_NODE()) return .absent;
    const style = (dom.style.computedStyle(node, null) catch null) orelse return .absent;
    const display = style.display();
    if (display.box == .none) return .absent;
    if (display.isBlockLevel() and !(editing.isEditableOrEditingHost(node) catch false)) return .noneditable_block;
    return .editable;
}

fn canonicalPositionIsEditable(node: *Instance, offset: u32) bool {
    const kind = interfaces.Node.get_nodeType(node) catch return false;
    if (kind == interfaces.Node.get_TEXT_NODE()) {
        // Q20's 16-row browser probe (2026-10-27): a hidden or empty Text
        // can focus its editable root. Chrome/Safari, unlike Firefox, do
        // not focus collapsible whitespace beside a noneditable block.
        if ((interfaces.CharacterData.get_length(node) catch 0) == 0 or
            !(editing.isWhitespaceNode(node) catch false)) return true;
        const p = parent(node) orelse return false;
        var index: u32 = 0;
        var current = interfaces.Node.get_firstChild(p) catch null;
        while (current) |child| : (current = interfaces.Node.get_nextSibling(child) catch null) {
            if (child == node) return canonicalPositionIsEditable(p, index);
            index += 1;
        }
        return false;
    }
    if (kind != interfaces.Node.get_ELEMENT_NODE()) return true;
    var left: Candidate = .absent;
    var right: Candidate = .absent;
    var index: usize = 0;
    var current = interfaces.Node.get_firstChild(node) catch null;
    while (current) |child| : (current = interfaces.Node.get_nextSibling(child) catch null) {
        const state = candidate(child);
        if (state != .absent) {
            if (index < offset) left = state else {
                right = state;
                break;
            }
        }
        index += 1;
    }
    // Q10 browser-majority canonicalization (2026-10-27): Chrome/Safari
    // leave focus alone where Firefox focuses the root. Collapsed whitespace
    // next to only a noneditable block supplies no
    // editable caret. Inline noneditable content still permits the host's
    // caret. An empty host does too. The Range itself is never rewritten.
    return left == .editable or right == .editable or (left == .absent and right == .absent);
}

pub fn focusPosition(node: *Instance, offset: u32) void {
    // Q20: inert descendants do not move focus, even in an editable root
    // (Chrome/Safari majority; Firefox focuses the root).
    if (focus.isHostInert(node)) return;
    const root = rootEditable(node) orelse return;
    if (!canonicalPositionIsEditable(node, offset)) return;
    // Existing focusing steps handle root eligibility, delegation and
    // reentrant events. This is the final operation: listeners may replace
    // the Range, remove the target or navigate without a subsequent node read.
    if (!(dom.style.engine.isRenderedForFocus(root) catch false) or focus.isHostInert(root)) return;
    focus.focusingSteps(root, null, .other);
}
