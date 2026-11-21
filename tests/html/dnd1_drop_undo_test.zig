//! Lane dnd1: a drop into an editing host is one undo step of its own.
//!
//! HTML 6.11.5 step 4's drop default action inserts the dragged text/plain
//! into the editing host (src/html/drag_and_drop.zig -> execcommand
//! insertFromDrop). Chrome records it as one step (DragController::
//! ConcludeEditDrag -> ReplaceSelectionCommand, its own UndoStep), Firefox
//! as one transaction (HTMLEditor::InsertFromDataTransfer under an
//! AutoPlaceholderBatch), Safari as one EditCommandComposition: undo takes
//! the whole drop back, and typing before it is a separate step.
const std = @import("std");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const user_input = html.user_input;

fn element(page: helpers.Page, selector: []const u8) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    const document = context.document_instance orelse return error.NoDocument;
    return (try dom.selector_matching.querySelector(document, selector)) orelse error.NoElement;
}

/// Drag #src onto #host with the pointer: press, move onto the host (the
/// drag starts; with no positions the threshold counts as passed), release.
fn dragSourceOntoHost(page: helpers.Page) !void {
    const source = try element(page, "#src");
    const host = try element(page, "#host");
    var pointer = user_input.Pointer{};
    user_input.pointerMove(&pointer, source, .{});
    user_input.pointerDown(&pointer, 0, .{});
    user_input.pointerMove(&pointer, host, .{});
    user_input.pointerMove(&pointer, host, .{});
    user_input.pointerUp(&pointer, 0, .{});
    user_input.pointerGone(&pointer);
    try page.turn();
}

const markup =
    \\document.body.innerHTML = '<span id=src draggable=true>src</span><div id=host contenteditable>ab</div>';
    \\src.addEventListener('dragstart', e => e.dataTransfer.setData('text/plain', 'XY'));
    \\globalThis.inputs = [];
    \\host.addEventListener('beforeinput', e => inputs.push('before:' + e.inputType));
    \\host.addEventListener('input', e => inputs.push('input:' + e.inputType));
;

fn dropUndoesAsOneStep() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(markup);
    // Typing first: its own (typing) step.
    try page.run("host.focus(); getSelection().collapse(host.firstChild, 2); document.execCommand('insertText', false, 'c');");
    try harness.expectEval(page, "host.textContent", "abc");
    try page.run("inputs.length = 0;");
    try dragSourceOntoHost(page);
    try harness.expectEval(page, "host.textContent", "abcXY");
    try harness.expectEval(page, "inputs.join()", "before:insertFromDrop,input:insertFromDrop");
    // One undo takes the whole drop back, and only the drop.
    try harness.expectEval(page, "String(document.execCommand('undo')) + ' ' + host.textContent", "true abc");
    // The typing is the step before it.
    try harness.expectEval(page, "String(document.execCommand('undo')) + ' ' + host.textContent", "true ab");
    // Redo replays both, the drop as one step.
    try harness.expectEval(page, "document.execCommand('redo'); host.textContent", "abc");
    try harness.expectEval(page, "document.execCommand('redo'); host.textContent", "abcXY");
}

test "a drop into a contenteditable is one undo step, apart from the typing before it" {
    try helpers.onFreshThread(dropUndoesAsOneStep);
}
