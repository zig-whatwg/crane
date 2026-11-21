//! Lane edit3: Selection.modify(..., "lineboundary") and the Home and End
//! keys in an editing host (Blink's LogicalStartOfLine / LogicalEndOfLine
//! through its SelectionModifier, which the key bindings MoveToBeginningOf-
//! Line / MoveToEndOfLine run too) where no renderer is needed: the line
//! ends at a forced break, a block edge or the host's edge before any soft
//! wrap could. Where a soft wrap could come first, the selection stays - a
//! renderer's read (src/html/execcommand/visible_position.zig
//! logicalLineBoundary). Both cases are pinned here.
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const script =
    \\globalThis.focusAfter = (markup, find, offset, direction, alter) => {
    \\  document.body.innerHTML = markup;
    \\  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    \\  let text = null;
    \\  while (walker.nextNode()) if (walker.currentNode.data.includes(find)) { text = walker.currentNode; break; }
    \\  getSelection().collapse(text, offset);
    \\  getSelection().modify(alter || 'move', direction, 'lineboundary');
    \\  const s = getSelection();
    \\  const describe = (n, o) => (n.nodeType === 3 ? JSON.stringify(n.data) : n.nodeName) + '@' + o;
    \\  return describe(s.anchorNode, s.anchorOffset) + (s.isCollapsed ? '' : '..' + describe(s.focusNode, s.focusOffset));
    \\};
;

fn modifyCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(script);
    const Row = struct { call: []const u8, expected: []const u8 };
    const rows = [_]Row{
        // One word: no soft wrap opportunity, so the line is the host's.
        .{ .call = "focusAfter('<div contenteditable>abc</div>', 'abc', 1, 'forward')", .expected = "\"abc\"@3" },
        .{ .call = "focusAfter('<div contenteditable>abc</div>', 'abc', 2, 'backward')", .expected = "\"abc\"@0" },
        // white-space: nowrap never wraps softly.
        .{ .call = "focusAfter('<div contenteditable style=\"white-space:nowrap\">abc def</div>', 'abc', 1, 'forward')", .expected = "\"abc def\"@7" },
        // A br ends the line; collapsed white-space before the first word is
        // not where the line starts.
        .{ .call = "focusAfter('<div contenteditable>abc<br>def</div>', 'abc', 1, 'forward')", .expected = "\"abc\"@3" },
        .{ .call = "focusAfter('<div contenteditable>abc<br>def</div>', 'def', 2, 'backward')", .expected = "\"def\"@0" },
        .{ .call = "focusAfter('<div contenteditable> abc</div>', 'abc', 3, 'backward')", .expected = "\" abc\"@1" },
        // A preserved line feed ends it too.
        .{ .call = "focusAfter('<div contenteditable style=\"white-space:pre\">ab cd\\nef gh</div>', 'ab', 1, 'forward')", .expected = "\"ab cd\\nef gh\"@5" },
        // Extending.
        .{ .call = "focusAfter('<div contenteditable>abc</div>', 'abc', 1, 'forward', 'extend')", .expected = "\"abc\"@1..\"abc\"@3" },
        // Where a soft wrap could come first - a space, a wbr - the
        // selection stays: the renderer's line boxes decide.
        .{ .call = "focusAfter('<div contenteditable>abc def</div>', 'abc', 1, 'forward')", .expected = "\"abc def\"@1" },
        .{ .call = "focusAfter('<div contenteditable>abc def</div>', 'abc', 6, 'backward')", .expected = "\"abc def\"@6" },
        .{ .call = "focusAfter('<div contenteditable>abc<wbr>def</div>', 'abc', 1, 'forward')", .expected = "\"abc\"@1" },
    };
    var failures: usize = 0;
    for (rows) |row| {
        const actual = try page.evaluate(row.call);
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, row.expected)) {
            std.debug.print("{s}: expected {s}, got {s}\n", .{ row.call, row.expected, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "Selection.modify lineboundary answers the lines no renderer is needed for" {
    try helpers.onFreshThread(modifyCases);
}

fn pressKey(page: helpers.Page, key: html.user_input.Key, modifiers: html.user_input.Modifiers) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, key, modifiers);
    html.user_input.keyUp(&keyboard, document, key, modifiers);
}

fn homeEndKeys() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    const end: html.user_input.Key = .{ .key = "End", .code = "End", .key_code = 35 };
    const home: html.user_input.Key = .{ .key = "Home", .code = "Home", .key_code = 36 };
    try page.run("setupHost('ab[]cd').focus();");
    pressKey(page, end, .{});
    try harness.expectEval(page, "getSelection().focusOffset + ',' + getSelection().isCollapsed", "4,true");
    pressKey(page, home, .{ .shift = true });
    try harness.expectEval(page, "getSelection().anchorOffset + ',' + getSelection().focusOffset", "4,0");
    // A line a soft wrap could end first: the caret stays.
    try page.run("setupHost('ab[]c def').focus();");
    pressKey(page, end, .{});
    try harness.expectEval(page, "String(getSelection().focusOffset)", "2");
}

test "Home and End move the caret to the line's ends where no renderer is needed" {
    try helpers.onFreshThread(homeEndKeys);
}
