//! Lane editing4: the paragraph commands reached from text and keys - the
//! insertText action's step 5 ("If value is a newline (U+000A), take the
//! action for the insertParagraph command and return true",
//! specs/w3c/execCommand.md) and the Editing spec's "Additional
//! requirements": Enter runs insertParagraph and Shift+Enter
//! insertLineBreak, each announced by a cancelable beforeinput at the
//! editing host (src/html/user_input.zig -> execcommand root.zig
//! lineBreakByKey). Expected results are tests/wpt/editing/data rows that
//! Chrome 156, Firefox 158 and Safari 27 all pass (wpt.fyi 5af3c135c9).
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const events_script =
    \\globalThis.events = [];
    \\document.getElementById('host').addEventListener('beforeinput', (ev) => events.push('beforeinput:' + ev.inputType + ':' + ev.data + ':' + ev.cancelable));
    \\document.getElementById('host').addEventListener('input', (ev) => events.push('input:' + ev.inputType + ':' + ev.data));
;

fn pressEnter(page: helpers.Page, shift: bool) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    const key: html.user_input.Key = .{ .key = "Enter", .code = "Enter", .key_code = 13, .text = "\r" };
    html.user_input.keyDown(&keyboard, document, key, .{ .shift = shift });
    html.user_input.keyUp(&keyboard, document, key, .{ .shift = shift });
}

fn newlineIsAParagraph() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(events_script);
    // insertText("\n") is insertParagraph's action
    // (editing/data/inserttext.js: "foo[]bar" in a <p>; insertparagraph.js
    // gives the same split for the command itself).
    try harness.expectEval(page, "runCommands('<p>foo[]bar</p>', [['inserttext', '\\n']]); hostHTML()", "<p>foo</p><p>bar</p>");
    try harness.expectEval(page, "runCommands('<p>foo[]bar</p>', [['insertparagraph', '']]); hostHTML()", "<p>foo</p><p>bar</p>");
    // Several characters, one of them a newline: the text on either side
    // goes into its paragraph.
    try harness.expectEval(page, "runCommands('<p>foo[]bar</p>', [['inserttext', 'a\\nb']]); hostHTML()", "<p>fooa</p><p>bbar</p>");
}

test "insertText with a newline takes insertParagraph's action" {
    try helpers.onFreshThread(newlineIsAParagraph);
}

fn enterKeys() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(events_script);
    // Enter: beforeinput insertParagraph (cancelable, no data), the
    // action, input.
    try page.run("setupHost('<p>foo[]bar</p>').focus(); events.length = 0;");
    pressEnter(page, false);
    try harness.expectEval(page, "hostHTML() + '|' + events.join(',')", "<p>foo</p><p>bar</p>|beforeinput:insertParagraph:null:true,input:insertParagraph:null");
    // Shift+Enter: insertLineBreak.
    try page.run("setupHost('<p>foo[]bar</p>').focus(); events.length = 0;");
    pressEnter(page, true);
    try harness.expectEval(page, "hostHTML() + '|' + events.join(',')", "<p>foo<br>bar</p>|beforeinput:insertLineBreak:null:true,input:insertLineBreak:null");
    // A cancelled beforeinput: nothing changes and no input fires.
    try page.run("setupHost('<p>foo[]bar</p>').focus(); events.length = 0; host.addEventListener('beforeinput', (e) => e.preventDefault(), { once: true });");
    pressEnter(page, false);
    try harness.expectEval(page, "hostHTML() + '|' + events.join(',')", "<p>foobar</p>|beforeinput:insertParagraph:null:true");
}

test "Enter runs insertParagraph and Shift+Enter insertLineBreak" {
    try helpers.onFreshThread(enterKeys);
}
