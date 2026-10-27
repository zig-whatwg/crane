//! Lane editing4: indent, outdent, insertOrderedList and
//! insertUnorderedList (specs/w3c/execCommand.md, "Indenting and
//! outdenting", "Toggling lists"), their states and indeterminacies, and
//! the delete command's step 10 (Backspace at an indentation element's
//! start outdents it). Expected results are tests/wpt/editing/data cases
//! that Chrome 156, Firefox 158 and Safari 27 all pass (wpt.fyi 5af3c135c9)
//! unless a case says otherwise.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const Case = harness.Case;
const indent: []const [2][]const u8 = &.{.{ "indent", "" }};
const outdent: []const [2][]const u8 = &.{.{ "outdent", "" }};
const ol: []const [2][]const u8 = &.{.{ "insertorderedlist", "" }};
const ul: []const [2][]const u8 = &.{.{ "insertunorderedlist", "" }};

const cases = [_]Case{
    // indent: a list item nests in a list of its parent's type, merging
    // with a neighbouring one.
    .{ .input = "<ol><li>foo<li>b[ar<li>baz]</ol>", .commands = indent, .expected = "<ol><li>foo</li><ol><li>bar</li><li>baz</li></ol></ol>" },
    .{ .input = "<ol><li>[foo]</li><ol><li>bar</ol><li>baz</ol>", .commands = indent, .expected = "<ol><ol><li>foo</li><li>bar</li></ol><li>baz</li></ol>" },
    .{ .input = "<ol><li>foo</li><ol><li>bar<li>baz</ol><li>[quz]</ol>", .commands = indent, .expected = "<ol><li>foo</li><ol><li>bar</li><li>baz</li><li>quz</li></ol></ol>" },
    .{ .input = "<ol><li>foo</li><ol><li>[bar]<li>baz</ol><li>quz</ol>", .commands = indent, .expected = "<ol><li>foo</li><ol><ol><li>bar</li></ol><li>baz</li></ol><li>quz</li></ol>" },
    // outdent: a simple indentation element goes; a nested one is split.
    .{ .input = "<blockquote><p>foo[bar]</p></blockquote><p>baz</p><p>extra", .commands = outdent, .expected = "<p>foobar</p><p>baz</p><p>extra</p>" },
    .{ .input = "<blockquote><blockquote>foo[bar]baz</blockquote></blockquote>", .commands = outdent, .expected = "<blockquote>foobarbaz</blockquote>" },
    .{ .input = "<blockquote><div>foo[bar]baz</div></blockquote>", .commands = outdent, .expected = "<div>foobarbaz</div>" },
    .{ .input = "<blockquote data-abc=def><blockquote>foo[bar]baz</blockquote></blockquote>", .commands = outdent, .expected = "<blockquote data-abc=\"def\">foobarbaz</blockquote>" },
    .{ .input = "<blockquote><p>foo[bar</p></blockquote><p>b]az</p><p>extra", .commands = outdent, .expected = "<p>foobar</p><p>baz</p><p>extra</p>" },
    // lists: a run of lists of the other type joins one list of this type.
    .{ .input = "foo<ul><li>[bar</ul><ol><li>baz]</ol>quz", .commands = ol, .expected = "foo<ol><li>bar</li><li>baz</li></ol>quz" },
    .{ .input = "foo<ol><li>[bar</ol><ul><li>baz]</ul>quz", .commands = ul, .expected = "foo<ul><li>bar</li><li>baz</li></ul>quz" },
    .{ .input = "{<table><tr><td>foo<td>bar<td>baz</table>}", .commands = ol, .expected = "<ol><li><table><tbody><tr><td>foo</td><td>bar</td><td>baz</td></tr></tbody></table></li></ol>" },
};

fn actions() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &cases);
}

test "indent, outdent and the list commands: the editing spec's actions" {
    try helpers.onFreshThread(actions);
}

fn listStates() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // "the selection's list state": ol, ul, mixed, none.
    try harness.expectEval(page, "setupHost('<ol><li>[foo]</li></ol>'); [document.queryCommandState('insertorderedlist'), document.queryCommandState('insertunorderedlist')].join()", "true,false");
    try harness.expectEval(page, "setupHost('<ul><li>[foo]</li></ul>'); [document.queryCommandState('insertorderedlist'), document.queryCommandState('insertunorderedlist')].join()", "false,true");
    try harness.expectEval(page, "setupHost('<ol><li>[foo</li></ol><ul><li>bar]</li></ul>'); [document.queryCommandIndeterm('insertorderedlist'), document.queryCommandIndeterm('insertunorderedlist')].join()", "true,true");
    try harness.expectEval(page, "setupHost('[foo]'); [document.queryCommandState('insertorderedlist'), document.queryCommandIndeterm('insertorderedlist')].join()", "false,false");
    // Toggling: insertOrderedList in an ol takes the item out of it, into
    // the default single-line container (toggle lists step 10, fix
    // disallowed ancestors).
    try harness.expectEval(page, "runCommands('<ol><li>[foo]</li></ol>', [['defaultparagraphseparator', 'div'], ['insertorderedlist', '']]); hostHTML()", "<div>foo</div>");
    // A selection left part in a list and part in the default single-line
    // container: "mixed ul" - state false, indeterm true - whichever
    // container the separator names (editing/run/insertunorderedlist.html
    // ?1001-2000; Chrome 156 and Safari 27 pass both).
    const after_split = "[hostHTML(), document.queryCommandState('insertunorderedlist'), document.queryCommandIndeterm('insertunorderedlist'), getSelection().getRangeAt(0).endContainer.parentNode.nodeName].join()";
    try harness.expectEval(page, "runCommands('<ul><li>foo<ul><li>b[ar</ul><li>b]az</ul>', [['defaultparagraphseparator', 'p'], ['insertunorderedlist', '']]); " ++ after_split, "<ul><li>foo</li><li>bar</li></ul><p>baz</p>,false,true,P");
    try harness.expectEval(page, "runCommands('<ul><li>foo<ul><li>b[ar</ul><li>b]az</ul>', [['defaultparagraphseparator', 'div'], ['insertunorderedlist', '']]); " ++ after_split, "<ul><li>foo</li><li>bar</li></ul><div>baz</div>,false,true,DIV");
}

test "insertOrderedList and insertUnorderedList: state and indeterminacy" {
    try helpers.onFreshThread(listStates);
}

fn tableCellLists() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // editing/run/insert-list-items-in-table-cell.html: a selection whose
    // boundary points sit in rows (the data's `data-start` / `data-end` on
    // a <tr>) or on the table, then insertOrderedList once and twice.
    try page.run(
        \\globalThis.table_markup = '<div contenteditable="true"><table><tr><td>fsdf</td><td>fsdf</td></tr><tr><td>gghfg</td><td>fsfg</td></tr></table></div>';
        \\globalThis.listCells = (pick, times) => {
        \\  const host = document.getElementById('host');
        \\  host.innerHTML = table_markup;
        \\  const [s, so, e, eo] = pick(host);
        \\  const r = document.createRange();
        \\  r.setStart(s, so);
        \\  r.setEnd(e, eo);
        \\  getSelection().removeAllRanges();
        \\  getSelection().addRange(r);
        \\  for (let i = 0; i < times; i++) document.execCommand('insertOrderedList', false, i === 0 ? '' : '1');
        \\  return [hostHTML(), document.queryCommandState('insertOrderedList'), document.queryCommandIndeterm('insertOrderedList')].join('|');
        \\};
        \\globalThis.firstRow = (h) => { const tr = h.querySelectorAll('tr'); return [tr[0], 0, tr[0], 2]; };
        \\globalThis.bothRows = (h) => { const tr = h.querySelectorAll('tr'); return [tr[0], 0, tr[1], 2]; };
        \\globalThis.wholeTable = (h) => { const t = h.querySelector('table'); return [t, 0, t, 1]; };
    );
    const plain = "<div contenteditable=\"true\"><table><tbody><tr><td>fsdf</td><td>fsdf</td></tr><tr><td>gghfg</td><td>fsfg</td></tr></tbody></table></div>";
    // One row: each of its cells gets a list (the spec already does this:
    // block-extending stays inside the table).
    try harness.expectEval(page, "listCells(firstRow, 1)", "<div contenteditable=\"true\"><table><tbody><tr><td><ol><li>fsdf</li></ol></td><td><ol><li>fsdf</li></ol></td></tr><tr><td>gghfg</td><td>fsfg</td></tr></tbody></table></div>|false|false");
    // From the first row's start to the last row's end: block-extending
    // leaves the table, and the spec would put the whole table in one list
    // item. Chrome 156 lists each cell, and Chrome and Safari 27 answer
    // false for the state afterwards (wpt.fyi 5af3c135c9).
    try harness.expectEval(page, "listCells(bothRows, 1)", "<div contenteditable=\"true\"><table><tbody><tr><td><ol><li>fsdf</li></ol></td><td><ol><li>fsdf</li></ol></td></tr><tr><td><ol><li>gghfg</li></ol></td><td><ol><li>fsfg</li></ol></td></tr></tbody></table></div>|false|false");
    // The second insertOrderedList takes every cell's list out again (all
    // three browsers).
    try harness.expectEval(page, "listCells(bothRows, 2)", plain ++ "|false|false");
    try harness.expectEval(page, "listCells(firstRow, 2)", plain ++ "|false|false");
    // A selection holding the table itself wraps it whole, and toggles it
    // back (the spec; all three browsers).
    try harness.expectEval(page, "listCells(wholeTable, 1)", "<div contenteditable=\"true\"><ol><li><table><tbody><tr><td>fsdf</td><td>fsdf</td></tr><tr><td>gghfg</td><td>fsfg</td></tr></tbody></table></li></ol></div>|true|false");
    try harness.expectEval(page, "listCells(wholeTable, 2)", plain ++ "|false|false");
}

test "the list commands in table cells: a cell bounds what a list takes" {
    try helpers.onFreshThread(tableCellLists);
}

fn backspaceOutdents() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // The delete command's step 10 with a previous line: the line joins it
    // (all three browsers; the spec would outdent).
    try harness.expectEval(page, "runCommands('foo<blockquote>[]bar</blockquote>', [['delete', '']]); hostHTML()", "foobar");
    // Step 7 keeps the spec's outdent of a first list item (never-trade).
    try harness.expectEval(page, "runCommands('foo<ol><li>[]bar<li>baz</ol>', [['defaultparagraphseparator', 'div'], ['delete', '']]); hostHTML()", "foo<div>bar</div><ol><li>baz</li></ol>");
    try harness.expectEval(page, "runCommands('<pre>abc</pre><blockquote>[]def</blockquote>', [['delete', '']]); hostHTML()", "<pre>abcdef</pre>");
}

test "delete: an indentation element joins the previous line, a first list item outdents" {
    try helpers.onFreshThread(backspaceOutdents);
}

fn plaintextOnly() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<div contenteditable=plaintext-only id=host><ul><li>abc</li></ul></div>'; const r = document.createRange(); r.selectNodeContents(host.querySelector('li')); getSelection().removeAllRanges(); getSelection().addRange(r);");
    // "This command must not be enabled if the editing host is in the
    // plaintext-only state" (indent, outdent, the list commands), and
    // formatBlock by the browsers (editing/plaintext-only/styling-commands.html).
    try harness.expectEval(page, "['indent','outdent','insertOrderedList','insertUnorderedList','formatBlock','insertHorizontalRule'].map((c) => document.queryCommandEnabled(c)).join()", "false,false,false,false,false,false");
    try harness.expectEval(page, "['insertParagraph','insertLineBreak'].map((c) => document.queryCommandEnabled(c)).join()", "true,true");
    try harness.expectEval(page, "document.execCommand('indent'); host.innerHTML", "<ul><li>abc</li></ul>");
}

test "block commands in a plaintext-only editing host" {
    try helpers.onFreshThread(plaintextOnly);
}
