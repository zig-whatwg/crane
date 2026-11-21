//! Lane edit3: InputEvent's target ranges (Input Events 2,
//! specs/w3c/input-events.md "target ranges"): the ones a script's
//! InputEventInit gives, returned by getTargetRanges(), and the ones the
//! editing keys' trusted beforeinput carries - the selection a Backspace or
//! a typed character replaces (Chrome and Firefox pass editing/other/delete-
//! without-unwrapping-first-line-of-child-block.html's getTargetRanges()
//! rows for both, wpt.fyi 2358bd4835).
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn pressKey(page: helpers.Page, key: html.user_input.Key) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, key, .{});
    html.user_input.keyUp(&keyboard, document, key, .{});
}

fn targetRanges() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // From script: the init dictionary's StaticRanges, the same objects.
    try harness.expectEval(page,
        \\(() => {
        \\  const sr = new StaticRange({ startContainer: document.body, startOffset: 0, endContainer: document.body, endOffset: 1 });
        \\  const ev = new InputEvent('beforeinput', { inputType: 'deleteContentBackward', targetRanges: [sr] });
        \\  const ranges = ev.getTargetRanges();
        \\  return [ranges.length, ranges[0] === sr, ev.getTargetRanges() !== ranges, new InputEvent('input').getTargetRanges().length].join(',');
        \\})()
    , "1,true,true,0");
    // From the keys: the selection they replace, as it was before.
    try page.run(
        \\globalThis.seen = [];
        \\host.addEventListener('beforeinput', (e) => {
        \\  for (const r of e.getTargetRanges()) seen.push(e.inputType + ':' + r.startContainer.nodeName + ',' + r.startOffset + '-' + r.endContainer.nodeName + ',' + r.endOffset + ':' + (r instanceof StaticRange));
        \\});
        \\setupHost('abc<br>{<br><div>d]ef</div>').focus();
    );
    pressKey(page, .{ .key = "Backspace", .code = "Backspace", .key_code = 8 });
    try page.run("setupHost('a[bc]d').focus();");
    pressKey(page, .{ .key = "x", .code = "KeyX", .key_code = 88, .text = "x" });
    // A caret's Backspace carries none yet (see root.zig selectionTargetRange).
    try page.run("setupHost('abc[]').focus();");
    pressKey(page, .{ .key = "Backspace", .code = "Backspace", .key_code = 8 });
    try harness.expectEval(page, "seen.join('|')", "deleteContentBackward:DIV,2-#text,1:true|insertText:#text,1-#text,3:true");
}

test "InputEvent target ranges: the init dictionary's, and the keys' beforeinput selection" {
    try helpers.onFreshThread(targetRanges);
}
