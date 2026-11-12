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

/// The focus() side of the same pairing: focusing a root editable element
/// puts the caret at its start unless the selection is already in it.
/// Blink and WebKit Element::UpdateSelectionOnFocus with focus()'s
/// SelectionBehaviorOnFocus::kRestore ("if this is not the selection's root
/// editable element, collapse to FirstPositionInOrBeforeNode(this)", core/
/// dom/element.cc); Gecko HTMLEditor::OnFocus -> EditorBase::
/// InitializeSelection collapses into the focused editing host likewise.
/// Without it `host.focus(); document.execCommand(...)` finds no range:
/// editing/other/inserttext-after-bold-in-font-face-monospace.html and
/// selectall-in-editinghost.html row 1 pass in Chrome 157, Firefox 160 and
/// Safari 27.2 (wpt.fyi 24ddf405a0). Script focus only: a click places the
/// caret at its hit position (Blink passes kNone for mouse focus). Runs
/// before the focusing steps, so focus listeners see the caret.
pub fn caretOnFocus(element: *Instance) void {
    const root = rootEditable(element) orelse return;
    if (root != element) return;
    // Only where the focusing steps will focus it (focusPosition's checks).
    if (focus.isHostInert(element)) return;
    if (!(dom.style.engine.isRenderedForFocus(element) catch false)) return;
    const document = interfaces.Node.get_ownerDocument(element) catch return;
    const selection = (interfaces.Document.call_getSelection(document orelse return) catch return) orelse return;
    if ((interfaces.Selection.get_rangeCount(selection) catch 0) > 0) {
        if (interfaces.Selection.get_anchorNode(selection) catch null) |anchor| {
            if (rootEditable(anchor) == element) return;
        }
    }
    interfaces.Selection.call_collapse(selection, element, .passed(0)) catch {};
}

/// A primary-button press that hit the editable element `hit` (mousedown's
/// default action, after its focus): the caret goes to the hit position -
/// Blink's SelectionController::HandleMousePressEvent (PositionForPoint of
/// the hit), Gecko's nsIFrame::HandlePress (GetContentOffsetsFromPoint),
/// WebKit's the same. Which position a point maps to is geometry, a read
/// on the renderer (docs/platform-protocol.md 6.9) - except for an element
/// with exactly one caret position, an empty one, where every renderer
/// answers the same: (element, 0) (the integrator's G5 ruling, 2026-11-12:
/// DOM fact, not a stand-in). editing/other/empty-elements-insertion.html's
/// border row and empty-elements-insertion-padding.html: all three pass.
/// TODO(renderer position-for-point): the layout adapter
/// (src/platform/layout_adapter.zig) offers caret rects only, no
/// position-for-point read, so a press on an element with content places
/// no caret until a renderer answers that read.
pub fn caretAtHit(hit: *Instance) void {
    if ((interfaces.Node.get_nodeType(hit) catch return) != interfaces.Node.get_ELEMENT_NODE()) return;
    if (!(editing.isEditable(hit) catch false) and !(editing.isEditingHost(hit) catch false)) return;
    // One caret position only: no child nodes.
    if ((interfaces.Node.get_firstChild(hit) catch return) != null) return;
    const document = (interfaces.Node.get_ownerDocument(hit) catch return) orelse return;
    const selection = (interfaces.Document.call_getSelection(document) catch return) orelse return;
    interfaces.Selection.call_collapse(selection, hit, .passed(0)) catch {};
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
