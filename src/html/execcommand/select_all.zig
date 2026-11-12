//! The selectAll command (specs/w3c/execCommand.md, "The selectAll
//! command"), from document.execCommand("selectAll") and from the
//! select-all shortcut (Ctrl+A, or Meta+A where navigator.platform names a
//! Mac: user_input.zig).
//!
//! One deviation, golden rule 2 (no newer spec; the spec's own note says
//! "This is totally broken: if executed inside an editing host, it has to
//! select the editing host contents, not the whole document"): with the
//! active range in an editing host, the target is that host, not the body.
//! Chrome 157, Firefox 159 and Safari 27.2 all select the host's contents
//! when the selection is in it or collapsed in an <input> or <textarea>
//! inside it (editing/other/selectall-in-editinghost.html rows 1, 3 and 4 at
//! wpt.fyi stable). Blink: FrameSelection::SelectAll takes the highest
//! editable root of a content-editable selection (core/editing/
//! frame_selection.cc); Gecko: HTMLEditor::SelectAllInternal selects the
//! focused editing host's contents. With no range, the spec's body - which
//! Chrome and Safari also select there (row 2: they fail it, Firefox selects
//! the focused host; majority).
//!
//! Outside an editing host, the spec's step 3 - selectAllChildren(body) - is
//! kept although Chrome and Safari leave the selection collapsed there: a
//! SCOPED exception to golden rule 2's majority clause, ruled by the user
//! 2026-11-11 (integrator 23:44 UTC, option (b)), for this case only.
//! editing/other/selectall-without-focus.html at wpt.fyi 24ddf405a0: Chrome
//! 157 0/3, Firefox 160 3/3, Safari 27.2 0/3. Chrome and Safari differ
//! through mechanisms Crane does not model: Blink/WebKit's VisibleSelection
//! adjustment shrinks a selection that crosses into an editing host (the
//! body there ends with one), and FrameSelection::SelectAll selects a text
//! control's inner value when the selection is collapsed at an <input> or
//! <textarea>, leaving the DOM selection collapsed; with no such boundary
//! all three select the document (selectall-in-editinghost.html row 2).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const common = @import("common.zig");

const Edit = common.Edit;
const Instance = runtime.Instance;

/// The node selectAll selects the children of: the editing host holding
/// the active range's start (the browsers' rule above), else step 1's body
/// or document element; null when there is none.
pub fn target(edit: *Edit) !?*Instance {
    // The browsers' editing-host target (module comment).
    if (try edit.rangeStart()) |start| {
        if (try common.isEditableOrEditingHost(start.node)) {
            if (try common.editingHostOf(start.node)) |host| {
                // A document-wide host (designMode, <html contenteditable>):
                // its body, the spec's target and Gecko's editor root
                // (HTMLEditor::GetRoot is the body of an HTML document).
                const body = try interfaces.Document.get_body(edit.document);
                const document_element = try interfaces.Document.get_documentElement(edit.document);
                return if (host == document_element and body != null) body.? else host;
            }
        }
    }
    // Step 1: the body element, else the document element.
    return (try interfaces.Document.get_body(edit.document)) orelse
        try interfaces.Document.get_documentElement(edit.document);
}

/// The selectAll command's action. Always true (step 4).
pub fn action(edit: *Edit) !bool {
    if (try target(edit)) |t| {
        // Step 3.
        try interfaces.Selection.call_selectAllChildren(edit.selection, t);
    } else {
        // Step 2.
        try interfaces.Selection.call_removeAllRanges(edit.selection);
    }
    // Step 4.
    return true;
}
