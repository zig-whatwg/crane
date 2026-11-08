//! Lane forms1 batch 2: the arrow keys move a focused textarea's caret, as
//! they move an input's (batch 1, C7a). A user's caret movement changes the
//! text control selection and schedules selectionchange (Selection API
//! 3.1); it fires no select event - that is "set the selection range" step 6,
//! for script's setSelectionRange() - so the move does not go through that
//! algorithm. ArrowLeft and ArrowRight move one grapheme cluster (Blink
//! FrameSelection::Modify by character, WebKit the same); with Shift they
//! extend from the anchor; without it, a range collapses to its start or end
//! (Blink SelectionModifier::ModifyMovingLeft/Right). Typing then inserts at
//! the moved caret, in the normalized API value the selection counts (docs/
//! lessons/spec-compliance-editor-text-and-selection-must-use-the-same-value.md).
const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const user_input = html.user_input;

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn press(page: helpers.Page, key: []const u8, text: ?[]const u8, shift: bool) !void {
    var keyboard: user_input.Keyboard = .{};
    const document = try documentOf(page);
    user_input.keyDown(&keyboard, document, .{ .key = key, .text = text }, .{ .shift = shift });
    user_input.keyUp(&keyboard, document, .{ .key = key, .text = text }, .{ .shift = shift });
}

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

// An expression: a top-level `const` would persist across evaluations.
const selection_of = "((t) => t.selectionStart + ',' + t.selectionEnd + ',' + t.selectionDirection)(document.getElementById('t'))";

/// A focused textarea holding `a<emoji>b`, CR LF, `c` (API value "a😀b\nc",
/// 6 code units), its caret at the end - set by script, whose events have
/// fired by the time the keys are pressed.
fn openTextarea() !helpers.Page {
    const page = try helpers.Page.open();
    errdefer page.close();
    try page.run(
        \\document.body.innerHTML = '<textarea id=t>a\u{1F600}b\r\nc</textarea>';
        \\globalThis.selects = 0;
        \\globalThis.changes = 0;
        \\const area = document.getElementById('t');
        \\area.addEventListener('select', () => ++globalThis.selects);
        \\document.addEventListener('selectionchange', () => ++globalThis.changes);
        \\area.focus();
        \\area.setSelectionRange(6, 6);
    );
    try page.turn();
    try expectScript(page, "document.getElementById('t').value.length + ',' + document.getElementById('t').selectionStart", "6,6");
    try page.run("globalThis.selects = 0; globalThis.changes = 0;");
    return page;
}

fn arrowsMoveByGrapheme() !void {
    const page = try openTextarea();
    defer page.close();
    try press(page, "ArrowLeft", null, false);
    try expectScript(page, selection_of, "5,5,none");
    // Over the line feed, then b, then the whole surrogate pair.
    try press(page, "ArrowLeft", null, false);
    try press(page, "ArrowLeft", null, false);
    try expectScript(page, selection_of, "3,3,none");
    try press(page, "ArrowLeft", null, false);
    try expectScript(page, selection_of, "1,1,none");
    try press(page, "ArrowRight", null, false);
    try expectScript(page, selection_of, "3,3,none");
    // Typing goes in at the caret.
    try press(page, "x", "x", false);
    try expectScript(page, "JSON.stringify(document.getElementById('t').value) + ',' + document.getElementById('t').selectionStart", "\"a\u{1F600}xb\\nc\",4");
    try page.turn();
    // A caret move is no setSelectionRange(): no select event; the
    // selection changed, so selectionchange fired.
    try expectScript(page, "globalThis.selects + ',' + (globalThis.changes > 0)", "0,true");
}

test "the arrow keys move a focused textarea's caret by grapheme cluster, with no select event" {
    try helpers.onFreshThread(arrowsMoveByGrapheme);
}

fn shiftExtendsAndArrowCollapses() !void {
    const page = try openTextarea();
    defer page.close();
    try press(page, "ArrowLeft", null, true);
    try press(page, "ArrowLeft", null, true);
    try expectScript(page, selection_of, "4,6,backward");
    try press(page, "ArrowRight", null, true);
    try expectScript(page, selection_of, "5,6,backward");
    // Without Shift a range collapses to its start (left) or end (right).
    try press(page, "ArrowLeft", null, false);
    try expectScript(page, selection_of, "5,5,none");
    try press(page, "ArrowLeft", null, true);
    try press(page, "ArrowRight", null, false);
    try expectScript(page, selection_of, "5,5,none");
    try page.turn();
    try expectScript(page, "String(globalThis.selects)", "0");
}

test "Shift with an arrow key extends a textarea's selection from its anchor; an arrow alone collapses it" {
    try helpers.onFreshThread(shiftExtendsAndArrowCollapses);
}

fn readonlyTextareaCaretMoves() !void {
    // Navigation applies to a readonly control too (lane sd1's word keys;
    // Blink and WebKit move the caret of a readonly textarea).
    const page = try openTextarea();
    defer page.close();
    try page.run("document.getElementById('t').readOnly = true;");
    try press(page, "ArrowLeft", null, false);
    try expectScript(page, selection_of, "5,5,none");
}

test "a readonly textarea's caret moves" {
    try helpers.onFreshThread(readonlyTextareaCaretMoves);
}
