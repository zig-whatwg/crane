//! Lane edit3: execCommand("undo") and ("redo") over each editing command's
//! own primitive changes (src/html/execcommand/undo.zig over the Document's
//! history, src/html/editing/history.zig) - Blink's UndoStack of UndoSteps of
//! SimpleEditCommands, Gecko's TransactionManager.
//!
//! The cases are WPT's: editing/run/undo-redo.html (every case passes in
//! Chrome 157, Firefox 160 and Safari 27.2), editing/other/undo-
//! insertparagraph-after-moving-split-nodes.html (all three) and
//! editing/run/undo-redo-after-mutation.html's rows all three pass (wpt.fyi
//! aligned runs at 2358bd4835). The last tests pin the history's lifetime:
//! typing merges into one step, and a destroyed document with a full history
//! lets go of every node it held.
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const undo_script =
    \\globalThis.undoRedo = (markup, command) => {
    \\  setupHost(markup);
    \\  const initial = hostHTML();
    \\  document.execCommand(command);
    \\  const after = hostHTML();
    \\  const undone = document.execCommand('undo');
    \\  const afterUndo = hostHTML();
    \\  const redone = document.execCommand('redo');
    \\  const afterRedo = hostHTML();
    \\  const again = document.execCommand('redo');
    \\  const problems = [];
    \\  if (afterUndo !== initial) problems.push('undo gave ' + afterUndo + ' for ' + initial);
    \\  if (!undone) problems.push('undo returned false');
    \\  if (afterRedo !== after) problems.push('redo gave ' + afterRedo + ' for ' + after);
    \\  if (!redone) problems.push('redo returned false');
    \\  if (again) problems.push('a second redo returned true');
    \\  if (hostHTML() !== after) problems.push('a second redo changed ' + hostHTML());
    \\  return problems.length ? markup + ' ' + command + ': ' + problems.join('; ') : 'ok';
    \\};
;

const UndoCase = struct { markup: []const u8, command: []const u8 };

// editing/run/undo-redo.html.
const undo_redo_cases = [_]UndoCase{
    .{ .markup = "<p>[]abcdef</p>", .command = "insertParagraph" },
    .{ .markup = "<p>abc[]def</p>", .command = "insertParagraph" },
    .{ .markup = "<p>abcdef[]</p>", .command = "insertParagraph" },
    .{ .markup = "<ul><li>[]abcdef</li></ul>", .command = "insertParagraph" },
    .{ .markup = "<ul><li>abc[]def</li></ul>", .command = "insertParagraph" },
    .{ .markup = "<ul><li>abcdef[]</li></ul>", .command = "insertParagraph" },
    .{ .markup = "<p>[]abcdef</p>", .command = "insertLineBreak" },
    .{ .markup = "<p>abc[]def</p>", .command = "insertLineBreak" },
    .{ .markup = "<p>abcdef[]</p>", .command = "insertLineBreak" },
    .{ .markup = "<ul><li>[]abcdef</li></ul>", .command = "insertLineBreak" },
    .{ .markup = "<ul><li>abc[]def</li></ul>", .command = "insertLineBreak" },
    .{ .markup = "<ul><li>abcdef[]</li></ul>", .command = "insertLineBreak" },
    .{ .markup = "<p>abc</p><p>[]def</p>", .command = "delete" },
    .{ .markup = "<p>abc[]</p><p>def</p>", .command = "forwardDelete" },
    .{ .markup = "<p>abc\u{1F449}</p><p>[]\u{1F448}def</p>", .command = "delete" },
    .{ .markup = "<p>abc\u{1F449}[]</p><p>\u{1F448}def</p>", .command = "forwardDelete" },
    .{ .markup = "<p>A line</p><p>[]Second line with <b contenteditable='false'>non-editable item</b></p>", .command = "delete" },
    // The other commands' steps undo the same way.
    .{ .markup = "<p>foo[bar]baz</p>", .command = "bold" },
    .{ .markup = "<p>[foo<b>bar</b>baz]</p>", .command = "removeFormat" },
    .{ .markup = "<p>foo[]bar</p>", .command = "insertHorizontalRule" },
    .{ .markup = "<p>[foo</p><p>bar]</p>", .command = "insertOrderedList" },
};

fn undoRedoCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(undo_script);
    var failures: usize = 0;
    for (undo_redo_cases) |case| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "undoRedo({f}, {f})", .{ std.json.fmt(case.markup, .{}), std.json.fmt(case.command, .{}) });
        defer std.testing.allocator.free(source);
        const result = try page.evaluate(source);
        defer std.testing.allocator.free(result);
        if (!std.mem.eql(u8, result, "ok")) {
            std.debug.print("{s}\n", .{result});
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "undo and redo replay each command's own changes (editing/run/undo-redo.html)" {
    try helpers.onFreshThread(undoRedoCases);
}

fn pressKey(page: helpers.Page, key: html.user_input.Key, modifiers: html.user_input.Modifiers) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, key, modifiers);
    html.user_input.keyUp(&keyboard, document, key, modifiers);
}

const enter: html.user_input.Key = .{ .key = "Enter", .code = "Enter", .key_code = 13, .text = "\r" };

fn movedSplitNodes() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("document.execCommand('defaultParagraphSeparator', false, 'div');");
    // editing/other/undo-insertparagraph-after-moving-split-nodes.html: the
    // right <div> moved after the <p> is still merged back into the left.
    try page.run("setupHost('<div>abc[]def</div><p>ghi</p>').focus();");
    pressKey(page, enter, .{});
    try page.run("host.appendChild(host.querySelector('div + div')); document.execCommand('undo');");
    try harness.expectEval(page, "hostHTML()", "<div>abcdef</div><p>ghi</p>");
    // The left one moved before the <p>.
    try page.run("setupHost('<p>abc</p><div>def[]ghi</div>').focus();");
    pressKey(page, enter, .{});
    try page.run("host.insertBefore(host.querySelector('div'), host.querySelector('p')); document.execCommand('undo');");
    try harness.expectEval(page, "hostHTML()", "<div>defghi</div><p>abc</p>");
    // The right one moved into the left one.
    try page.run("setupHost('<div>abc[]def</div>').focus();");
    pressKey(page, enter, .{});
    try page.run("{ const l = host.querySelector('div'), r = host.querySelector('div + div'); l.insertBefore(r, l.firstChild); } document.execCommand('undo');");
    try harness.expectEval(page, "hostHTML()", "<div>abcdef</div>");
    // The left one moved into the right one: the right one goes, and the
    // left one, out of the document, gets its text back.
    try page.run("setupHost('<div>abc[]def</div>').focus();");
    pressKey(page, enter, .{});
    try page.run("globalThis.left = host.querySelector('div'); host.querySelector('div + div').appendChild(left); document.execCommand('undo');");
    try harness.expectEval(page, "hostHTML() + '|' + left.innerHTML", "|abcdef");
}

test "undo puts back what insertParagraph split after script moved the parts" {
    try helpers.onFreshThread(movedSplitNodes);
}

fn redoAfterMutation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // editing/run/undo-redo-after-mutation.html's rows all three pass.
    const Row = struct { markup: []const u8, caret: []const u8, mutate: []const u8, expected: []const u8 };
    const rows = [_]Row{
        .{ .markup = "<i>will be removed</i> abc", .caret = "host.lastChild, host.lastChild.length", .mutate = "host.firstChild.remove()", .expected = " abc<br><br>" },
        .{ .markup = "abc", .caret = "host.firstChild, host.firstChild.length", .mutate = "{ const i = document.createElement('i'); i.textContent = ' appended text'; host.appendChild(i); }", .expected = "abc<i> appended text</i><br><br>" },
        .{ .markup = "abc", .caret = "host.firstChild, host.firstChild.length", .mutate = "{ const i = document.createElement('i'); i.textContent = 'inserted text '; host.insertBefore(i, host.firstChild); }", .expected = "<i>inserted text </i>abc<br><br>" },
        .{ .markup = "<b>will be removed</b><i>abc</i>", .caret = "host.querySelector('b').firstChild, host.querySelector('b').firstChild.length", .mutate = "host.querySelector('b').remove()", .expected = "<i>abc</i>" },
        .{ .markup = "<b>abc</b><i>will be removed</i>", .caret = "host.querySelector('b').firstChild, host.querySelector('b').firstChild.length", .mutate = "host.querySelector('i').remove()", .expected = "<b>abc<br></b>" },
    };
    var failures: usize = 0;
    for (rows) |row| {
        const source = try std.fmt.allocPrint(std.testing.allocator,
            \\(() => {{
            \\  host.innerHTML = {f};
            \\  getSelection().collapse({s});
            \\  document.execCommand('insertLineBreak');
            \\  document.execCommand('undo');
            \\  const undone = host.innerHTML;
            \\  {s};
            \\  document.execCommand('redo');
            \\  return undone + '|' + host.innerHTML;
            \\}})()
        , .{ std.json.fmt(row.markup, .{}), row.caret, row.mutate });
        defer std.testing.allocator.free(source);
        const result = try page.evaluate(source);
        defer std.testing.allocator.free(result);
        const expected = try std.fmt.allocPrint(std.testing.allocator, "{s}|{s}", .{ row.markup, row.expected });
        defer std.testing.allocator.free(expected);
        if (!std.mem.eql(u8, result, expected)) {
            std.debug.print("{s}: expected {s}, got {s}\n", .{ row.markup, expected, result });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "redo after script mutated the editing host (editing/run/undo-redo-after-mutation.html)" {
    try helpers.onFreshThread(redoAfterMutation);
}

fn typingMerges() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("globalThis.inputs = []; host.addEventListener('input', (e) => inputs.push(e.inputType));");
    // Typed text is one step while the caret stays where typing left it
    // (Blink TypingCommand): one undo takes all of it.
    try page.run("setupHost('<p>abc[]</p>').focus();");
    const a: html.user_input.Key = .{ .key = "x", .code = "KeyX", .key_code = 88, .text = "x" };
    const b: html.user_input.Key = .{ .key = "y", .code = "KeyY", .key_code = 89, .text = "y" };
    pressKey(page, a, .{});
    pressKey(page, b, .{});
    try harness.expectEval(page, "hostHTML()", "<p>abcxy</p>");
    try harness.expectEval(page, "inputs.length = 0; String(document.execCommand('undo')) + hostHTML() + inputs.join(',')", "true<p>abc</p>historyUndo");
    try harness.expectEval(page, "String(document.execCommand('redo')) + hostHTML()", "true<p>abcxy</p>");
    // A selection change closes the typing step: two steps.
    try page.run("setupHost('<p>abc[]</p>').focus();");
    pressKey(page, a, .{});
    try page.run("getSelection().collapse(host.firstChild.firstChild, 1);");
    pressKey(page, b, .{});
    try harness.expectEval(page, "hostHTML()", "<p>aybcx</p>");
    try harness.expectEval(page, "document.execCommand('undo'); hostHTML()", "<p>abcx</p>");
    try harness.expectEval(page, "document.execCommand('undo'); hostHTML()", "<p>abc</p>");
}

test "typing merges into one undo step until the selection moves" {
    try helpers.onFreshThread(typingMerges);
}

fn destroyedDocumentLetsGo() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // A frame whose document builds a history holding nodes in its tree and
    // out of it (the joined paragraph's removed <p>), then goes: its
    // destruction lets go of every hold (refcount step 7b), so the nodes are
    // garbage with their document and the Browser's end finds none alive.
    try page.run(
        \\globalThis.frame = document.createElement('iframe');
        \\document.body.appendChild(frame);
        \\const doc = frame.contentDocument;
        \\doc.body.innerHTML = '<div contenteditable><p>abc</p><p>def</p></div>';
        \\const host = doc.querySelector('div');
        \\host.focus();
        \\doc.getSelection().collapse(host.lastChild.firstChild, 0);
        \\doc.execCommand('delete');
        \\doc.execCommand('insertParagraph');
        \\doc.execCommand('insertText', false, 'xyz');
        \\doc.execCommand('undo');
        \\globalThis.frameHTML = host.innerHTML;
    );
    try harness.expectEval(page, "frameHTML", "<p>abc</p><p>def</p>");
    // And a frame whose editor state holds nothing: a configuration command
    // made it, and no command changed the tree.
    try page.run(
        \\globalThis.emptyFrame = document.createElement('iframe');
        \\document.body.appendChild(emptyFrame);
        \\emptyFrame.contentDocument.execCommand('styleWithCSS', false, 'true');
        \\emptyFrame.contentDocument.body.innerHTML = '<div contenteditable>abc</div>';
        \\emptyFrame.contentDocument.getSelection().collapse(emptyFrame.contentDocument.querySelector('div').firstChild, 0);
        \\emptyFrame.contentDocument.execCommand('justifyLeft');
    );
    try page.run("frame.remove(); frame = null; emptyFrame.remove(); emptyFrame = null; collectNow();");
    try page.turn();
    try page.run("collectNow();");
}

test "a destroyed document's undo history lets go of the nodes it held, and an empty editor state of none" {
    try helpers.onFreshThread(destroyedDocumentLetsGo);
}
