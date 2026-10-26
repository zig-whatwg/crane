//! Lane editing2: a deletion from the start of a line into a child block
//! leaves the block whole (Gecko's AutoBlockElementsJoiner mode
//! DeletePrecedingLinesAndContentInRange; Chrome and Firefox), and
//! insertText deletes a non-collapsed selection first (the Editing spec's
//! insertText action step 1). Cases from
//! editing/other/delete-without-unwrapping-first-line-of-child-block.html
//! (expected: its first accepted entry) and, for what must still join,
//! editing/run/delete.html.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

const setup_script =
    \\document.body.innerHTML = '<div contenteditable id=host></div>';
    \\globalThis.setupHost = (markup, pre) => {
    \\  const host = document.getElementById('host');
    \\  host.style.whiteSpace = pre ? 'pre' : 'normal';
    \\  host.innerHTML = markup;
    \\  const idx = (n) => Array.prototype.indexOf.call(n.parentNode.childNodes, n);
    \\  let s = null, so = 0, e = null, eo = 0;
    \\  const walker = document.createTreeWalker(host, NodeFilter.SHOW_TEXT);
    \\  const texts = [];
    \\  while (walker.nextNode()) texts.push(walker.currentNode);
    \\  for (const t of texts) {
    \\    let d = t.data, i;
    \\    if ((i = d.indexOf('[')) !== -1) { d = d.slice(0, i) + d.slice(i + 1); s = t; so = i; }
    \\    if ((i = d.indexOf('{')) !== -1) { d = d.slice(0, i) + d.slice(i + 1); s = t.parentNode; so = idx(t) + (i === 0 ? 0 : 1); }
    \\    if ((i = d.indexOf(']')) !== -1) { d = d.slice(0, i) + d.slice(i + 1); e = t; eo = i; }
    \\    if ((i = d.indexOf('}')) !== -1) { d = d.slice(0, i) + d.slice(i + 1); e = t.parentNode; eo = idx(t) + (i === 0 ? 0 : 1); }
    \\    t.data = d;
    \\  }
    \\  for (const t of texts) {
    \\    if (t.data !== '') continue;
    \\    const parent = t.parentNode, i = idx(t);
    \\    if (s === t) { s = parent; so = i; } else if (s === parent && so > i) so--;
    \\    if (e === t) { e = parent; eo = i; } else if (e === parent && eo > i) eo--;
    \\    parent.removeChild(t);
    \\  }
    \\  const range = document.createRange();
    \\  range.setStart(s, so);
    \\  if (e) range.setEnd(e, eo); else range.setEnd(s, so);
    \\  getSelection().removeAllRanges();
    \\  getSelection().addRange(range);
    \\  return host;
    \\};
    \\globalThis.hostHTML = () => document.getElementById('host').innerHTML;
;

const Case = struct {
    input: []const u8,
    command: []const u8,
    /// innerHTML after the command, then after insertText "X".
    after: []const u8,
    after_typing: []const u8,
    pre: bool = false,
};

const cases = [_]Case{
    // br lines (the WPT file's lineBreak=br).
    .{ .input = "abc<br>{<br><div id=\"child\">]def<br>ghi</div>", .command = "delete", .after = "abc<br><div id=\"child\">def<br>ghi</div>", .after_typing = "abc<br><div id=\"child\">Xdef<br>ghi</div>" },
    .{ .input = "<br>[abc<br><div id=\"child\">]def<br>ghi</div>", .command = "delete", .after = "<br><div id=\"child\">def<br>ghi</div>", .after_typing = "<br><div id=\"child\">Xdef<br>ghi</div>" },
    .{ .input = "<br>{<br><div id=\"child\">]def<br>ghi</div>", .command = "forwardDelete", .after = "<br><div id=\"child\">def<br>ghi</div>", .after_typing = "<br><div id=\"child\">Xdef<br>ghi</div>" },
    .{ .input = "{<br><br><div id=\"child\">]def<br>ghi</div>", .command = "delete", .after = "<div id=\"child\">def<br>ghi</div>", .after_typing = "<div id=\"child\">Xdef<br>ghi</div>" },
    .{ .input = "[abc<br><br><div id=\"child\">]def<br>ghi</div>", .command = "forwardDelete", .after = "<div id=\"child\">def<br>ghi</div>", .after_typing = "<div id=\"child\">Xdef<br>ghi</div>" },
    .{ .input = "abc<br>{<br><div id=\"child\">d]ef<br>ghi</div>", .command = "delete", .after = "abc<br><div id=\"child\">ef<br>ghi</div>", .after_typing = "abc<br><div id=\"child\">Xef<br>ghi</div>" },
    .{ .input = "<br><div id=\"child\">[]def<br>ghi</div>", .command = "delete", .after = "<div id=\"child\">def<br>ghi</div>", .after_typing = "<div id=\"child\">Xdef<br>ghi</div>" },
    .{ .input = "<b><br></b><div id=\"child\">[]def<br>ghi</div>", .command = "delete", .after = "<div id=\"child\">def<br>ghi</div>", .after_typing = "<div id=\"child\">Xdef<br>ghi</div>" },
    // Preformatted line breaks (lineBreak=preformat).
    .{ .input = "abc\n[\n<div id=\"child\">]def<br>ghi</div>", .command = "delete", .after = "abc\n<div id=\"child\">def<br>ghi</div>", .after_typing = "abc\n<div id=\"child\">Xdef<br>ghi</div>", .pre = true },
    .{ .input = "\n[abc\n<div id=\"child\">]def<br>ghi</div>", .command = "forwardDelete", .after = "\n<div id=\"child\">def<br>ghi</div>", .after_typing = "\n<div id=\"child\">Xdef<br>ghi</div>", .pre = true },
    .{ .input = "[abc\n\n<div id=\"child\">]def<br>ghi</div>", .command = "delete", .after = "<div id=\"child\">def<br>ghi</div>", .after_typing = "<div id=\"child\">Xdef<br>ghi</div>", .pre = true },
    // Backspace at the block's start: an empty line before it goes alone.
    .{ .input = "abc<br><br><div id=\"child\">[]def<br>ghi</div>", .command = "delete", .after = "abc<br><div id=\"child\">def<br>ghi</div>", .after_typing = "abc<br><div id=\"child\">Xdef<br>ghi</div>" },
    .{ .input = "<b>abc<br><br></b><div id=\"child\">[]def<br>ghi</div>", .command = "delete", .after = "<b>abc<br></b><div id=\"child\">def<br>ghi</div>", .after_typing = "<b>abc<br></b><div id=\"child\">Xdef<br>ghi</div>" },
    .{ .input = "abc\n\n<div id=\"child\">[]def<br>ghi</div>", .command = "delete", .after = "abc\n<div id=\"child\">def<br>ghi</div>", .after_typing = "abc\n<div id=\"child\">Xdef<br>ghi</div>", .pre = true },
    .{ .input = "\n<div id=\"child\">[]def<br>ghi</div>", .command = "delete", .after = "<div id=\"child\">def<br>ghi</div>", .after_typing = "<div id=\"child\">Xdef<br>ghi</div>", .pre = true },
    // A line that is only a br moves as the spec says, and goes where it
    // is extraneous (editing/run/delete.html and forwarddelete.html).
    .{ .input = "foo{}<p><br></p>", .command = "forwardDelete", .after = "foo", .after_typing = "fooX" },
    .{ .input = "<ol><li>foo<br><br></li></ol>{}<br>", .command = "delete", .after = "<ol><li>foo<br><br></li></ol>", .after_typing = "<ol><li>foo<br>X<br></li></ol>" },
    .{ .input = "<p>foo</p>{<p>bar}</p><p>baz</p>", .command = "delete", .after = "<p>foo</p><br><p>baz</p>", .after_typing = "<p>foo</p>X<br><p>baz</p>" },
    // A range the forwardDelete action built from a caret still joins.
    .{ .input = "<ol><ol><li>foo</li></ol><li>{}<br><ol><li>bar</li></ol></li></ol>", .command = "forwardDelete", .after = "<ol><ol><li>foo</li></ol><li>bar</li></ol>", .after_typing = "<ol><ol><li>foo</li></ol><li>Xbar</li></ol>" },
    // Still joins: a range from the middle of a line, or a collapsed br
    // that only ends the line before (editing/run/delete.html).
    .{ .input = "foo<br><p>[]bar</p>", .command = "delete", .after = "foobar", .after_typing = "fooXbar" },
    .{ .input = "foo<br><br><p>[]bar</p>", .command = "delete", .after = "foo<br><p>bar</p>", .after_typing = "foo<br><p>Xbar</p>" },
    .{ .input = "ab[c<br><div id=\"child\">]def<br>ghi</div>", .command = "delete", .after = "abdef<div id=\"child\">ghi</div>", .after_typing = "abXdef<div id=\"child\">ghi</div>" },
};

fn childBlockCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    const a = std.testing.allocator;
    var failures: usize = 0;
    for (cases) |case| {
        const deleting = try std.fmt.allocPrint(a, "setupHost({f}, {}); document.execCommand({f}, false, ''); hostHTML()", .{ std.json.fmt(case.input, .{}), case.pre, std.json.fmt(case.command, .{}) });
        defer a.free(deleting);
        const after = try page.evaluate(deleting);
        defer a.free(after);
        if (!std.mem.eql(u8, after, case.after)) {
            failures += 1;
            std.debug.print("{s} at {s}: expected {s}, got {s}\n", .{ case.command, case.input, case.after, after });
            continue;
        }
        const typed = try page.evaluate("document.execCommand('insertText', false, 'X'); hostHTML()");
        defer a.free(typed);
        if (!std.mem.eql(u8, typed, case.after_typing)) {
            failures += 1;
            std.debug.print("insertText after {s} at {s}: expected {s}, got {s}\n", .{ case.command, case.input, case.after_typing, typed });
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "a deletion from a line start into a child block keeps the block" {
    try helpers.onFreshThread(childBlockCases);
}

const Replace = struct { input: []const u8, expected: []const u8, pre: bool = false };

const replacing = [_]Replace{
    // insertText over a non-collapsed selection deletes it first, keeping
    // the child block.
    .{ .input = "abc<br>{<br><div id=\"child\">]def<br>ghi</div>", .expected = "abc<br><div id=\"child\">Xdef<br>ghi</div>" },
    .{ .input = "<br>[abc<br><div id=\"child\">d]ef<br>ghi</div>", .expected = "<br><div id=\"child\">Xef<br>ghi</div>" },
    .{ .input = "\n[abc\n<div id=\"child\">]def<br>ghi</div>", .expected = "\n<div id=\"child\">Xdef<br>ghi</div>", .pre = true },
    // The emptied inline the caret is in stays, so the text keeps its style
    // (editing/run/inserttext.html; the browsers' typing style).
    .{ .input = "foo<b>[bar]</b>baz", .expected = "foo<b>X</b>baz" },
    .{ .input = "fo[o<b>b]ar</b>baz", .expected = "foX<b>ar</b>baz" },
    .{ .input = "<p>fo[o</p><p>b]ar</p>", .expected = "<p>foXar</p>" },
    // The padding br in the emptied wrapper goes (insertText step 14.1).
    .{ .input = "<blockquote><font color=blue>[foo]</font></blockquote>", .expected = "<blockquote><font color=\"blue\">X</font></blockquote>" },
    // Wrappers that do not hold the range's start go (Chrome and Firefox).
    .{ .input = "<div>abc[<b><i><img src=\"about:blank\">def]</i></b>ghi</div>", .expected = "<div>abcXghi</div>" },
    .{ .input = "<div>abc{<b><i><img src=\"about:blank\">def</i></b>]ghi</div>", .expected = "<div>abcXghi</div>" },
};

fn insertTextReplaces() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    const a = std.testing.allocator;
    var failures: usize = 0;
    for (replacing) |case| {
        const source = try std.fmt.allocPrint(a, "setupHost({f}, {}); document.execCommand('insertText', false, 'X'); hostHTML()", .{ std.json.fmt(case.input, .{}), case.pre });
        defer a.free(source);
        const actual = try page.evaluate(source);
        defer a.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) {
            failures += 1;
            std.debug.print("insertText at {s}: expected {s}, got {s}\n", .{ case.input, case.expected, actual });
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "insertText deletes a non-collapsed selection first" {
    try helpers.onFreshThread(insertTextReplaces);
}
