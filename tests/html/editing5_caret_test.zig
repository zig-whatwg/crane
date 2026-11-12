//! Lane editing5 batch 3: where the caret goes from the user's keys and
//! presses in an editing host - a primary press on an empty editable element
//! (selection_focus.caretAtHit, the integrator's G5 ruling: only where every
//! renderer answers the same), Tab and focus() to the first caret position
//! (caretOnSequentialFocus / caretOnFocus), ArrowLeft/Right and the word
//! modifier with Backspace (user_input.zig, execcommand root.zig
//! deleteWordByKey).
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn document(page: helpers.Page) *@import("runtime").Instance {
    return page.browser.current_context.?.document_instance.?;
}

fn element(page: helpers.Page, id: []const u8) !*@import("runtime").Instance {
    const interfaces = @import("interfaces");
    const runtime = @import("runtime");
    return (try interfaces.Document.call_getElementById(document(page), runtime.DOMString.initInterned(id))) orelse error.NoElement;
}

fn click(page: helpers.Page, target: *@import("runtime").Instance) void {
    var pointer: html.user_input.Pointer = .{};
    html.user_input.pointerMove(&pointer, target, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    html.user_input.pointerUp(&pointer, 0, .{});
    _ = page;
}

fn press(page: helpers.Page, key: html.user_input.Key, modifiers: html.user_input.Modifiers) void {
    var keyboard: html.user_input.Keyboard = .{};
    html.user_input.keyDown(&keyboard, document(page), key, modifiers);
    html.user_input.keyUp(&keyboard, document(page), key, modifiers);
}

const caret_script =
    \\globalThis.caret = () => {
    \\  const s = getSelection();
    \\  if (!s.rangeCount) return 'none';
    \\  const n = s.anchorNode;
    \\  return (n.nodeType === 3 ? JSON.stringify(n.data) : n.localName + (n.id ? '#' + n.id : '')) + '@' + s.anchorOffset + (s.isCollapsed ? '' : '+');
    \\};
;

fn clickPlacesCaretOnlyInAnEmptyElement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(caret_script);
    try page.run("document.body.innerHTML = '<div contenteditable><p><strong id=empty></strong></p><p id=full>abc</p></div>'; getSelection().removeAllRanges();");
    // An empty element has one caret position: the press puts the caret
    // there, and typed text goes into it (editing/other/empty-elements-
    // insertion.html's border row).
    click(page, try element(page, "empty"));
    try harness.expectEval(page, "caret()", "strong#empty@0");
    try harness.expectEval(page, "document.execCommand('insertText', false, 'a'); document.getElementById('empty').innerHTML", "a");
    // A press on content places no caret without a renderer's
    // position-for-point read: the selection stays where it was.
    try page.run("getSelection().removeAllRanges();");
    click(page, try element(page, "full"));
    try harness.expectEval(page, "caret()", "none");
}

test "a press on an empty editable element puts the caret in it, and on content none" {
    try helpers.onFreshThread(clickPlacesCaretOnlyInAnEmptyElement);
}

const tab: html.user_input.Key = .{ .key = "Tab", .code = "Tab", .key_code = 9 };

fn focusAndTabPutTheCaretAtTheFirstPosition() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(caret_script);
    // editing/run/caret-navigation-after-removing-line-break.html's spans:
    // white-space pre-wrap keeps the leading space a position.
    try page.run(
        \\document.body.innerHTML = '<style>span { white-space: pre-wrap }</style><span id=a contenteditable> abcd </span>111<span id=b contenteditable> efgh </span><div id=c contenteditable>\n  <p>ijkl</p></div>';
    );
    try page.run("document.getElementById('a').focus();");
    try harness.expectEval(page, "caret()", "\" abcd \"@0");
    // Tab: the next root editable element, its caret at its first position
    // (Blink's kReset), wherever the selection was.
    press(page, tab, .{});
    try harness.expectEval(page, "document.activeElement.id + ' ' + caret()", "b \" efgh \"@0");
    // Collapsible leading white-space is no position: the first text inside.
    press(page, tab, .{});
    try harness.expectEval(page, "document.activeElement.id + ' ' + caret()", "c \"ijkl\"@0");
}

test "focus() and Tab put the caret at the first caret position of an editing host" {
    try helpers.onFreshThread(focusAndTabPutTheCaretAtTheFirstPosition);
}

const arrow_right: html.user_input.Key = .{ .key = "ArrowRight", .code = "ArrowRight", .key_code = 39 };
const arrow_left: html.user_input.Key = .{ .key = "ArrowLeft", .code = "ArrowLeft", .key_code = 37 };
const backspace: html.user_input.Key = .{ .key = "Backspace", .code = "Backspace", .key_code = 8 };

fn wordModifier(page: helpers.Page) !html.user_input.Modifiers {
    const name = try page.evaluate("navigator.platform");
    defer std.testing.allocator.free(name);
    return if (std.mem.indexOf(u8, name, "Mac") != null) .{ .alt = true } else .{ .ctrl = true };
}

fn arrowsAndWordDelete() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(caret_script);
    try page.run("globalThis.events = []; host.addEventListener('beforeinput', (e) => events.push(e.inputType)); setupHost('ab[]cd').focus(); setupHost('ab[]cd');");
    // ArrowRight / ArrowLeft move the caret by a character.
    press(page, arrow_right, .{});
    try harness.expectEval(page, "caret()", "\"abcd\"@3");
    press(page, arrow_left, .{});
    press(page, arrow_left, .{});
    try harness.expectEval(page, "caret()", "\"abcd\"@1");
    // Shift extends; an unshifted arrow then collapses to the range's edge.
    press(page, arrow_right, .{ .shift = true });
    try harness.expectEval(page, "caret()", "\"abcd\"@1+");
    press(page, arrow_left, .{});
    try harness.expectEval(page, "caret()", "\"abcd\"@1");
    // The word modifier with Backspace deletes the word before the caret,
    // as deleteWordBackward (editing/whitespaces/delete-last-word-in-
    // inline-block-editing-host.html).
    try page.run("setupHost('a b[]'); events.length = 0;");
    press(page, backspace, try wordModifier(page));
    try harness.expectEval(page, "hostHTML() + '|' + events.join()", "a&nbsp;|deleteWordBackward");
}

test "arrow keys move the caret in an editing host; the word modifier with Backspace deletes a word" {
    try helpers.onFreshThread(arrowsAndWordDelete);
}
