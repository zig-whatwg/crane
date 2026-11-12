//! Lane editing5 batch 3: where the caret goes from the user's keys and
//! presses in an editing host - a primary press on an empty editable element
//! (selection_focus.caretAtHit, the integrator's G5 ruling: only where every
//! renderer answers the same), Tab and focus() to the first caret position
//! (caretOnSequentialFocus / caretOnFocus) and ArrowLeft/Right
//! (user_input.zig).
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

fn textControlFocusMovesTheSelectionBeforeIt() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(caret_script);
    // html/interaction/focus/focus-selection.html: a focused text control
    // shows the document's selection just before it; a button leaves it.
    try page.run("document.body.innerHTML = '<div id=box tabindex=0><button>b</button><input id=t><input type=number id=n><input type=submit id=s></div>'; getSelection().collapse(box);");
    try page.run("box.querySelector('button').focus();");
    try harness.expectEval(page, "caret()", "div#box@0");
    try page.run("document.getElementById('t').focus();");
    try harness.expectEval(page, "caret()", "div#box@1");
    try page.run("document.getElementById('n').focus();");
    try harness.expectEval(page, "caret()", "div#box@2");
    try page.run("document.getElementById('s').focus();");
    try harness.expectEval(page, "caret()", "div#box@2");
}

test "focusing a text control collapses the selection just before it" {
    try helpers.onFreshThread(textControlFocusMovesTheSelectionBeforeIt);
}

test "focus() and Tab put the caret at the first caret position of an editing host" {
    try helpers.onFreshThread(focusAndTabPutTheCaretAtTheFirstPosition);
}

const arrow_right: html.user_input.Key = .{ .key = "ArrowRight", .code = "ArrowRight", .key_code = 39 };
const arrow_left: html.user_input.Key = .{ .key = "ArrowLeft", .code = "ArrowLeft", .key_code = 37 };

fn arrowKeys() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(caret_script);
    try page.run("globalThis.starts = 0; document.addEventListener('selectstart', (e) => { starts++; if (globalThis.cancelStart) e.preventDefault(); }); setupHost('ab[]cd').focus(); setupHost('ab[]cd');");
    // ArrowRight / ArrowLeft move the caret by a character.
    press(page, arrow_right, .{});
    try harness.expectEval(page, "caret()", "\"abcd\"@3");
    press(page, arrow_left, .{});
    press(page, arrow_left, .{});
    try harness.expectEval(page, "caret()", "\"abcd\"@1");
    // Shift extends, after a selectstart; an unshifted arrow then collapses
    // to the range's edge.
    press(page, arrow_right, .{ .shift = true });
    try harness.expectEval(page, "caret() + ' ' + starts", "\"abcd\"@1+ 1");
    press(page, arrow_left, .{});
    try harness.expectEval(page, "caret()", "\"abcd\"@1");
    // A cancelled selectstart leaves the caret.
    try page.run("globalThis.cancelStart = true;");
    press(page, arrow_right, .{ .shift = true });
    try harness.expectEval(page, "caret() + ' ' + starts", "\"abcd\"@1 2");
    // Nothing to extend over at the host's start: no selectstart.
    try page.run("globalThis.cancelStart = false; starts = 0; setupHost('[]ab');");
    press(page, arrow_left, .{ .shift = true });
    try harness.expectEval(page, "caret() + ' ' + starts", "\"ab\"@0 0");
}

test "arrow keys move the caret in an editing host; Shift starts a selection with selectstart" {
    try helpers.onFreshThread(arrowKeys);
}
