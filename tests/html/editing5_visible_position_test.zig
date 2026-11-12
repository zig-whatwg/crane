//! Lane editing5 batch 4: Selection.modify over visible positions (Blink's
//! VisiblePosition model, src/html/execcommand/visible_position.zig) - the
//! caret moves to the next place a caret can be, skipping white-space the
//! style system collapses and DOM positions no box shows - and word steps
//! over an inline formatting context's text, across inline element edges,
//! which the word-modifier Backspace and Delete keys delete.
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn document(page: helpers.Page) *@import("runtime").Instance {
    return page.browser.current_context.?.document_instance.?;
}

fn press(page: helpers.Page, key: html.user_input.Key, modifiers: html.user_input.Modifiers) void {
    var keyboard: html.user_input.Keyboard = .{};
    html.user_input.keyDown(&keyboard, document(page), key, modifiers);
    html.user_input.keyUp(&keyboard, document(page), key, modifiers);
}

const caret_script =
    \\globalThis.where = (n, o) => (n.nodeType === 3 ? JSON.stringify(n.data) : n.localName + (n.id ? '#' + n.id : '')) + '@' + o;
    \\globalThis.caret = () => {
    \\  const s = getSelection();
    \\  if (!s.rangeCount) return 'none';
    \\  return where(s.focusNode, s.focusOffset) + (s.isCollapsed ? '' : ' from ' + where(s.anchorNode, s.anchorOffset));
    \\};
    \\globalThis.move = (alter, direction, granularity) => { getSelection().modify(alter, direction, granularity); return caret(); };
;

fn leftToTheLineBreak() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(caret_script);
    // editing/run/caretnavigation.html (all three browsers): the white-
    // space between blocks has no box, so the position before the br is
    // the only one between "line 1" and "line 2".
    try page.run(
        \\document.body.innerHTML = '<div contenteditable id=a>\n  <div>line 1</div>\n  <br>\n  <div class=caret>line 2</div>\n</div>' +
        \\  '<div contenteditable id=b>\n  <img style="display:block;width:100px;height:100px">\n  <br>\n  <div class=caret>line 2</div>\n</div>';
    );
    try page.run("a.focus(); getSelection().collapse(a.querySelector('.caret'), 0);");
    try harness.expectEval(page, "move('move', 'left', 'character')", "div#a@3");
    try page.run("b.focus(); getSelection().collapse(b.querySelector('.caret'), 0);");
    try harness.expectEval(page, "move('move', 'left', 'character')", "div#b@3");
    // And back: right from the br's line goes to the start of "line 2",
    // the next line.
    try harness.expectEval(page, "move('move', 'right', 'character')", "\"line 2\"@0");
}

test "Selection.modify left from the start of a block after a br lands before the br" {
    try helpers.onFreshThread(leftToTheLineBreak);
}

fn collapsedWhiteSpaceIsNoPosition() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(caret_script);
    // "abc   def": the first space is shown, the two after it collapse; a
    // caret after the space and before "d" is one place.
    try page.run("document.body.innerHTML = '<div contenteditable id=host>abc   def</div>'; host.focus(); getSelection().collapse(host.firstChild, 3);");
    try harness.expectEval(page, "move('move', 'forward', 'character')", "\"abc   def\"@4");
    try harness.expectEval(page, "move('move', 'forward', 'character')", "\"abc   def\"@7");
    try harness.expectEval(page, "move('move', 'backward', 'character')", "\"abc   def\"@4");
    try harness.expectEval(page, "move('move', 'backward', 'character')", "\"abc   def\"@3");
    // A range collapses to its edge for a character move.
    try page.run("getSelection().setBaseAndExtent(host.firstChild, 1, host.firstChild, 2);");
    try harness.expectEval(page, "move('move', 'forward', 'character')", "\"abc   def\"@2");
    try page.run("getSelection().setBaseAndExtent(host.firstChild, 1, host.firstChild, 2);");
    try harness.expectEval(page, "move('move', 'backward', 'character')", "\"abc   def\"@1");
}

test "Selection.modify skips white-space the style system collapses" {
    try helpers.onFreshThread(collapsedWhiteSpaceIsNoPosition);
}

fn adjacentTextIsOnePlace() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(caret_script);
    // The end of "ab" and the start of "cd" are one caret position: a
    // character move from one goes past "c" (Blink's NextVisually-
    // DistinctCandidate; selection/contenteditable/modify-around-inline-
    // element-boundary.tentative.html "abc[]<span>def</span>": all three).
    try page.run(
        \\document.body.innerHTML = '<div contenteditable id=host><span id=s></span></div>';
        \\s.append('ab', 'cd'); host.focus(); getSelection().collapse(s.firstChild, 2);
    );
    try harness.expectEval(page, "move('move', 'forward', 'character')", "\"cd\"@1");
    try page.run("getSelection().collapse(s.lastChild, 0);");
    try harness.expectEval(page, "move('move', 'backward', 'character')", "\"ab\"@1");
}

test "Selection.modify treats the boundary of adjacent Text as one caret position" {
    try helpers.onFreshThread(adjacentTextIsOnePlace);
}

fn wordAcrossInlineElements() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(caret_script);
    // A word step reads the whole line's text, not one Text node's.
    try page.run("document.body.innerHTML = '<div contenteditable id=host>abc <span>def</span> ghi</div>'; host.focus(); getSelection().collapse(host.lastChild, 0);");
    try harness.expectEval(page, "getSelection().modify('extend', 'backward', 'word'); String(getSelection())", "def");
    try page.run("getSelection().collapse(host.firstChild, 0);");
    try harness.expectEval(page, "getSelection().modify('move', 'forward', 'word'); getSelection().modify('extend', 'forward', 'word'); String(getSelection())", "def ");
}

test "Selection.modify word steps cross inline element edges" {
    try helpers.onFreshThread(wordAcrossInlineElements);
}

const backspace: html.user_input.Key = .{ .key = "Backspace", .code = "Backspace", .key_code = 8 };
const delete: html.user_input.Key = .{ .key = "Delete", .code = "Delete", .key_code = 46 };

fn wordModifier(page: helpers.Page) !html.user_input.Modifiers {
    const platform = try page.evaluate("String(navigator.platform.includes('Mac'))");
    defer std.testing.allocator.free(platform);
    return if (std.mem.eql(u8, platform, "true")) .{ .alt = true } else .{ .ctrl = true };
}

fn wordDeletionAcrossInlineElements() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // The keys go to the focused element: focus the host, as WPT's
    // EditorTestUtils.setupEditingHost does.
    try page.run("document.getElementById('host').focus();");
    const modifiers = try wordModifier(page);
    // editing/whitespaces/delete-word-around-span.html and its forward
    // twin: wrapping the word in a span changes nothing deleted.
    const cases = [_]struct { markup: []const u8, reference: []const u8, forward: bool }{
        .{ .markup = "abc <span>def</span> ghi[]", .reference = "abc def ghi[]", .forward = false },
        .{ .markup = "abc <span>def</span>[] ghi", .reference = "abc def[] ghi", .forward = false },
        .{ .markup = "abc <span>def[]</span> ghi", .reference = "abc def[] ghi", .forward = false },
        .{ .markup = "abc <span>[]def</span> ghi", .reference = "abc []def ghi", .forward = false },
        .{ .markup = "[]abc <span>def</span> ghi", .reference = "[]abc def ghi", .forward = true },
        .{ .markup = "abc []<span>def</span> ghi", .reference = "abc []def ghi", .forward = true },
        .{ .markup = "abc <span>def</span>[] ghi", .reference = "abc def[] ghi", .forward = true },
    };
    var failures: usize = 0;
    for (cases) |case| {
        const key = if (case.forward) delete else backspace;
        var script: std.ArrayList(u8) = .empty;
        defer script.deinit(std.testing.allocator);
        try script.print(std.testing.allocator, "setupHost('{s}');", .{case.reference});
        try page.run(script.items);
        press(page, key, modifiers);
        const expected = try page.evaluate("host.innerText.replaceAll('\\u00a0', ' ')");
        defer std.testing.allocator.free(expected);
        script.clearRetainingCapacity();
        try script.print(std.testing.allocator, "setupHost('{s}');", .{case.markup});
        try page.run(script.items);
        press(page, key, modifiers);
        const actual = try page.evaluate("host.innerText.replaceAll('\\u00a0', ' ')");
        defer std.testing.allocator.free(actual);
        // Something was deleted, and the same as in the reference.
        const original = "abc def ghi";
        if (!std.mem.eql(u8, actual, expected) or std.mem.eql(u8, expected, original)) {
            std.debug.print("word deletion {s} ({s}): got \"{s}\", reference \"{s}\"\n", .{ case.markup, if (case.forward) "Delete" else "Backspace", actual, expected });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "the word modifier with Backspace or Delete deletes the same word whether or not a span wraps it" {
    try helpers.onFreshThread(wordDeletionAcrossInlineElements);
}

fn lastWordInInlineBlockHost() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // editing/whitespaces/delete-last-word-in-inline-block-editing-host.html
    // (all three browsers): the white-space left at the host's end stays
    // visible.
    try page.run(
        \\document.body.innerHTML = '<span contenteditable style="display: inline-block" id=host>a b</span>';
        \\host.focus(); getSelection().collapse(host.firstChild, 3);
    );
    press(page, backspace, try wordModifier(page));
    try harness.expectEval(page, "['a <br>', 'a&nbsp;'].includes(host.innerHTML) ? 'ok' : host.innerHTML", "ok");
}

test "deleting the last word of an inline-block editing host keeps its trailing white-space visible" {
    try helpers.onFreshThread(lastWordInInlineBlockHost);
}

fn backspaceEmptiesARootWithOnePosition() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(caret_script);
    // editing/other/fire-selection-change-on-deleting-empty-element.html's
    // second Backspace (Chrome, Firefox): the emptied heading is the root's
    // only caret position, so the root is emptied to a placeholder br and
    // the caret goes to its start (Blink's MakeEditableRootEmpty).
    try page.run("document.body.innerHTML = '<div contenteditable id=host><h1><br></h1></div>'; host.focus(); getSelection().collapse(host.firstChild, 0);");
    press(page, backspace, .{});
    try harness.expectEval(page, "host.innerHTML + ' ' + caret()", "<br> div#host@0");
    // A lone placeholder br in a block root stays.
    press(page, backspace, .{});
    try harness.expectEval(page, "host.innerHTML + ' ' + caret()", "<br> div#host@0");
    // With another position before it, Backspace is the delete action.
    try page.run("host.innerHTML = '<p>a</p><h1><br></h1>'; getSelection().collapse(host.lastChild, 0);");
    press(page, backspace, .{});
    try harness.expectEval(page, "host.firstChild.localName + ' ' + host.textContent", "p a");
}

test "Backspace at the only caret position of an editing host empties it to a placeholder" {
    try helpers.onFreshThread(backspaceEmptiesARootWithOnePosition);
}
