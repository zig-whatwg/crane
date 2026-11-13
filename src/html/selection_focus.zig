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
    if (selectionBeforeTextControl(element)) return;
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
    const first = firstCaretPosition(element);
    interfaces.Selection.call_collapse(selection, first.node, .passed(first.offset)) catch {};
}

/// Sequential focus navigation's side (Tab, Shift+Tab): a root editable
/// element it focuses gets the caret at its first position, wherever the
/// selection was - Blink's FocusController::AdvanceFocusInDocumentOrder
/// focuses with SelectionBehaviorOnFocus::kReset (Element::
/// UpdateSelectionOnFocus: "collapse to FirstPositionInOrBeforeNode",
/// canonicalized), Gecko's HTMLEditor::OnFocus -> EditorBase::
/// InitializeSelection likewise. Runs before the focusing steps, as
/// caretOnFocus. editing/run/caret-navigation-after-removing-line-break.html:
/// all three browsers.
pub fn caretOnSequentialFocus(element: *Instance) void {
    if (selectionBeforeTextControl(element)) return;
    const root = rootEditable(element) orelse return;
    if (root != element) return;
    if (focus.isHostInert(element)) return;
    if (!(dom.style.engine.isRenderedForFocus(element) catch false)) return;
    const document = interfaces.Node.get_ownerDocument(element) catch return;
    const selection = (interfaces.Document.call_getSelection(document orelse return) catch return) orelse return;
    const first = firstCaretPosition(element);
    interfaces.Selection.call_collapse(selection, first.node, .passed(first.offset)) catch {};
}

/// A text control taking the focus takes the selection into its own
/// editor, which the document's Selection shows as the point just before
/// the control in its parent: Blink's TextControlElement::
/// UpdateSelectionOnFocus restores the control's selection in its inner
/// editor, and DOMSelection reports a selection inside the UA shadow tree
/// at its host (ShadowAdjustedNode / Offset); Gecko collapses the document
/// selection before the control (bug 2032191). html/interaction/focus/
/// focus-selection.html: Chrome 157 and Firefox 160 pass, Safari 27.2
/// leaves the selection. Whether `element` was such a control (then the
/// caller is done).
fn selectionBeforeTextControl(element: *Instance) bool {
    if (!@import("user_input.zig").isTextControl(element)) return false;
    if (focus.isHostInert(element)) return true;
    if (!(dom.style.engine.isRenderedForFocus(element) catch false)) return true;
    const p = parent(element) orelse return true;
    const index = editing.indexOf(element) catch return true;
    const document = interfaces.Node.get_ownerDocument(element) catch return true;
    const selection = (interfaces.Document.call_getSelection(document orelse return true) catch return true) orelse return true;
    interfaces.Selection.call_collapse(selection, p, .passed(index)) catch {};
    return true;
}

const Position = struct { node: *Instance, offset: u32 };

/// The first caret position inside the root editable element `root`, as
/// Blink canonicalizes FirstPositionInOrBeforeNode(root)
/// (CreateVisiblePosition(...).DeepEquivalent()): down to the first Text
/// whose characters do not all collapse, at its first character that does
/// not (leading collapsible white-space - spaces, tabs and segment breaks
/// where the style's white-space collapses them, the rule innerText reads
/// - is not a position), or before the first atomic inline (a br, an img,
/// a form control, a non-editable element). No geometry: what collapses is
/// the style system's answer. The root itself, at 0, when it holds none.
fn firstCaretPosition(root: *Instance) Position {
    var current = interfaces.Node.get_firstChild(root) catch null;
    while (current) |node| {
        if (caretPositionAt(node)) |position| return position;
        current = nextInside(node, root, descendInto(node));
    }
    return .{ .node = root, .offset = 0 };
}

/// The first caret position `node` itself offers, if it is a leaf that
/// holds one.
fn caretPositionAt(node: *Instance) ?Position {
    if (editing.isText(node)) {
        var data = editing.textData(node) catch return null;
        defer data.deinit(node.ctx.allocator);
        const text = data.asSlice();
        if (text.len == 0) return null;
        if ((editing.whiteSpaceAround(node) catch return null).preservesSpaces()) return .{ .node = node, .offset = 0 };
        for (text, 0..) |byte, index| switch (byte) {
            ' ', '\t', '\n', '\r', '\x0c' => {},
            // ASCII white-space is one code unit a byte: the byte index is
            // the UTF-16 offset.
            else => return .{ .node = node, .offset = @intCast(index) },
        };
        return null;
    }
    if (!editing.isElement(node)) return null;
    if (editing.displayIsNone(node)) return null;
    const atomic = (editing.isHtmlElementIn(node, &.{ "br", "img", "hr", "input", "select", "textarea", "button", "video", "audio", "canvas", "iframe", "embed", "object", "meter", "progress" }) catch false) or
        !(editing.isEditable(node) catch false);
    if (!atomic) return null;
    const p = parent(node) orelse return null;
    return .{ .node = p, .offset = editing.indexOf(node) catch return null };
}

/// Whether the walk goes into `node`'s children: an editable element with
/// a display.
fn descendInto(node: *Instance) bool {
    if (!editing.isElement(node) or editing.displayIsNone(node)) return false;
    return editing.isEditable(node) catch false;
}

/// The next node in tree order inside `root` (into `node`'s children when
/// `descend`).
fn nextInside(node: *Instance, root: *Instance, descend: bool) ?*Instance {
    if (descend) if (interfaces.Node.get_firstChild(node) catch null) |child| return child;
    var current = node;
    while (current != root) {
        if (interfaces.Node.get_nextSibling(current) catch null) |sibling| return sibling;
        current = parent(current) orelse return null;
    }
    return null;
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
