//! Lane editing4: the insertParagraph, insertLineBreak and
//! insertHorizontalRule commands (specs/w3c/execCommand.md). Expected
//! results are tests/wpt/editing/data/insertparagraph.js,
//! insertlinebreak.js and inserthorizontalrule.js cases that Chrome 156,
//! Firefox 158 and Safari 27 all pass (wpt.fyi 5af3c135c9).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const Case = harness.Case;
const div: []const [2][]const u8 = &.{ .{ "defaultparagraphseparator", "div" }, .{ "insertparagraph", "" } };
const p_sep: []const [2][]const u8 = &.{ .{ "defaultparagraphseparator", "p" }, .{ "insertparagraph", "" } };
const para: []const [2][]const u8 = &.{.{ "insertparagraph", "" }};
const line_break: []const [2][]const u8 = &.{.{ "insertlinebreak", "" }};
const hr: []const [2][]const u8 = &.{.{ "inserthorizontalrule", "" }};

const paragraph_cases = [_]Case{
    .{ .input = "<p>foo[]bar</p>", .commands = div, .expected = "<p>foo</p><p>bar</p>" },
    .{ .input = "<div>foo[]bar</div>", .commands = div, .expected = "<div>foo</div><div>bar</div>" },
    .{ .input = "<h1>foo[]bar</h1>", .commands = para, .expected = "<h1>foo</h1><h1>bar</h1>" },
    .{ .input = "<p><b>foo[]bar</b></p>", .commands = div, .expected = "<p><b>foo</b></p><p><b>bar</b></p>" },
    .{ .input = "<p><b>foo[]</b></p>", .commands = div, .expected = "<p><b>foo</b></p><p><b><br></b></p>" },
    .{ .input = "<p><i><b>foo[]</b></i></p>", .commands = div, .expected = "<p><i><b>foo</b></i></p><p><i><b><br></b></i></p>" },
    .{ .input = "<p><a href=foo><b>foo[]bar</b></a></p>", .commands = div, .expected = "<p><a href=\"foo\"><b>foo</b></a></p><p><a href=\"foo\"><b>bar</b></a></p>" },
    .{ .input = "<div><a href=foo>foo[]</a></div>", .commands = p_sep, .expected = "<div><a href=\"foo\">foo</a></div><div><br></div>" },
    .{ .input = "<blockquote><p>foo[]</blockquote>", .commands = div, .expected = "<blockquote><p>foo</p><p><br></p></blockquote>" },
    .{ .input = "<blockquote><p>foo[]<p>bar</blockquote>", .commands = p_sep, .expected = "<blockquote><p>foo</p><p><br></p><p>bar</p></blockquote>" },
    .{ .input = "<dl><dt>foo[]bar<dd>baz</dl>", .commands = para, .expected = "<dl><dt>foo</dt><dt>bar</dt><dd>baz</dd></dl>" },
    .{ .input = "<dl><dt>[]foo<dd>bar</dl>", .commands = para, .expected = "<dl><dt><br></dt><dt>foo</dt><dd>bar</dd></dl>" },
    .{ .input = "<table><tr><td><p>foo[]bar</table>", .commands = div, .expected = "<table><tbody><tr><td><p>foo</p><p>bar</p></td></tr></tbody></table>" },
    .{ .input = "<ol><li>foo<li>{}<br></ol>", .commands = div, .expected = "<ol><li>foo</li></ol><div><br></div>" },
    .{ .input = "<ol><li>foo</li><ul><li>{}<br></ul></ol>", .commands = para, .expected = "<ol><li>foo</li><li><br></li></ol>" },
    .{ .input = "<p>foo[bar</p><h1>baz]quz</h1>", .commands = div, .expected = "<p>foo</p><p>quz</p>" },
    // The browsers' split: inline wrappers split deep, keeping their style
    // on an empty line; a link is not continued.
    .{ .input = "<p><b>[]foo</b></p>", .commands = div, .expected = "<p><b><br></b></p><p><b>foo</b></p>" },
    .{ .input = "<div><span style=\"color:rgb(0, 0, 255)\">foo[]</span><br></div>", .commands = div, .expected = "<div><span style=\"color:rgb(0, 0, 255)\">foo</span></div><div><span style=\"color:rgb(0, 0, 255)\"><br></span></div>" },
    .{ .input = "<p><a href=foo>foo[]</a></p>", .commands = div, .expected = "<p><a href=\"foo\">foo</a></p><p><br></p>" },
    .{ .input = "<p><a href=foo>[]foo</a></p>", .commands = div, .expected = "<p><br></p><p><a href=\"foo\">foo</a></p>" },
    .{ .input = "<b>foo[]</b>bar", .commands = div, .expected = "<div><b>foo</b></div><div>bar</div>" },
    .{ .input = "<span>foo[]</span>", .commands = para, .expected = "<div><span>foo</span></div><div><br></div>" },
    // White-space at the split stays visible; a no-break space before a br
    // stays one (canonicalize whitespace's non-breaking end).
    .{ .input = "<div>a[] b</div>", .commands = div, .expected = "<div>a</div><div>&nbsp;b</div>" },
    .{ .input = "<div>a []b</div>", .commands = div, .expected = "<div>a&nbsp;</div><div>b</div>" },
    .{ .input = "<div>abc [] </div>", .commands = div, .expected = "<div>abc</div><div><br></div>" },
    .{ .input = "<p><a href=foo>foo&nbsp;[]<br><br></a></p>", .commands = div, .expected = "<p><a href=\"foo\">foo&nbsp;</a></p><p><a href=\"foo\"><br><br></a></p>" },
    // An inline editing host takes a line break.
    .{ .input = "<h1 contenteditable=false><span contenteditable>ab[]cd</span></h1>", .commands = div, .expected = "<h1 contenteditable=\"false\"><span contenteditable=\"\">ab<br>cd</span></h1>" },
    .{ .input = "<p>[X]<span contenteditable=false>abc</span></p>", .commands = para, .expected = "<p><br></p><p><span contenteditable=\"false\">abc</span></p>" },
    .{ .input = "<div contenteditable=false><foo-bar contenteditable><div>foo[]bar</div></foo-bar></div>", .commands = div, .expected = "<div contenteditable=\"false\"><foo-bar contenteditable=\"\"><div>foo</div><div>bar</div></foo-bar></div>" },
};

const line_break_cases = [_]Case{
    .{ .input = "foo[]bar", .commands = line_break, .expected = "foo<br>bar" },
    .{ .input = "<p>foo[]<!--bar-->", .commands = line_break, .expected = "<p>foo<br><br><!--bar--></p>" },
    .{ .input = "<address><p>foo[]</address>", .commands = line_break, .expected = "<address><p>foo<br><br></p></address>" },
    .{ .input = "<ol><li><div>foo[]</ol>", .commands = line_break, .expected = "<ol><li><div>foo<br><br></div></li></ol>" },
    .{ .input = "<b id=x class=y>foo[]bar</b>", .commands = line_break, .expected = "<b id=\"x\" class=\"y\">foo<br>bar</b>" },
    .{ .input = "<dl><dd><div>[]foo</dl>", .commands = line_break, .expected = "<dl><dd><div><br>foo</div></dd></dl>" },
    .{ .input = "<p>foo</p>{}<br>", .commands = line_break, .expected = "<p>foo</p><br><br>" },
    .{ .input = "<h1>foo</h1>{}<br><h2>bar</h2>", .commands = line_break, .expected = "<h1>foo</h1><br><br><h2>bar</h2>" },
    .{ .input = "<ol><li><p>foo[]bar</ol>", .commands = line_break, .expected = "<ol><li><p>foo<br>bar</p></li></ol>" },
    .{ .input = "<dl><dt>[]foo<dd>bar</dl>", .commands = line_break, .expected = "<dl><dt><br>foo</dt><dd>bar</dd></dl>" },
};

const hr_cases = [_]Case{
    .{ .input = "foo[]bar", .commands = hr, .expected = "foo<hr>bar" },
    .{ .input = "<div>foo[bar]baz</div>", .commands = hr, .expected = "<div>foo<hr>baz</div>" },
    .{ .input = "<span>foo</span>{}<span>bar</span>", .commands = hr, .expected = "<span>foo</span><hr><span>bar</span>" },
    .{ .input = "<b>foo[]bar</b>", .commands = &.{ .{ "stylewithcss", "false" }, .{ "inserthorizontalrule", "" } }, .expected = "<b>foo</b><hr><b>bar</b>" },
    .{ .input = "<ul><li>foo[bar]baz</li></ul>", .commands = hr, .expected = "<ul><li>foo<hr>baz</li></ul>" },
    .{ .input = "<p>foo<p>{bar}<p>baz", .commands = &.{ .{ "defaultparagraphseparator", "div" }, .{ "inserthorizontalrule", "" } }, .expected = "<p>foo</p><hr><p>baz</p>" },
    .{ .input = "<center>foo[bar]baz</center>", .commands = hr, .expected = "<center>foo<hr>baz</center>" },
};

fn paragraphs() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // A finding of refcount step 7 (lane refcount9), queued in the feature queue: insertParagraph leaves ten
    // never-wrapped DocumentFragments still holding their creator reference, which the final sweep frees.
    @import("dom").refcount_teardown.allowLiveNodesAtAgentEnd(&page.browser.agent_host.deferred_teardown, "insertParagraph leaves never-wrapped fragments holding their creator reference (feature queue)");
    try page.run(harness.setup_script);
    try harness.runCases(page, &paragraph_cases);
}

test "insertParagraph: the editing spec's action" {
    try helpers.onFreshThread(paragraphs);
}

fn lineBreaks() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &line_break_cases);
}

test "insertLineBreak: the editing spec's action" {
    try helpers.onFreshThread(lineBreaks);
}

fn rules() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &hr_cases);
}

test "insertHorizontalRule: the editing spec's action" {
    try helpers.onFreshThread(rules);
}

fn caretAndEvents() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // After insertParagraph the caret is at the new container's start
    // (step 34), so typing continues on the new line.
    try harness.expectEval(page, "runCommands('<p>foo[]bar</p>', [['insertparagraph','']]); (() => { const s = getSelection(); return s.isCollapsed + ':' + s.anchorNode.nodeName + ':' + s.anchorNode.textContent + ':' + s.anchorOffset; })()", "true:P:bar:0");
    // insertLineBreak leaves the caret after the br (step 9).
    try harness.expectEval(page, "runCommands('foo[]bar', [['insertlinebreak','']]); (() => { const s = getSelection(); return s.isCollapsed + ':' + s.anchorNode.id + ':' + s.anchorOffset; })()", "true:host:2");
    // The input event names the command's input type.
    try harness.expectEval(page, "(() => { setupHost('foo[]bar'); const seen = []; host.addEventListener('input', (e) => seen.push(e.inputType), { once: true }); document.execCommand('insertParagraph'); return seen.join(); })()", "insertParagraph");
}

test "insertParagraph and insertLineBreak: caret and input event" {
    try helpers.onFreshThread(caretAndEvents);
}

fn typingStyleAcrossTheSplit() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // The style of the text insertParagraph deletes carries into the new
    // paragraph, as it does after an explicit delete: Chrome 156, Firefox
    // 158 and Safari 27 answer true for the bold state, and type bold
    // (editing/run/multitest.html ?9001-last, [styleWithCSS false,
    // insertparagraph, inserttext] rows; wpt.fyi 5af3c135c9).
    try harness.expectEval(page, "runCommands('<div>abc<b>[def]</b></div>', [['stylewithcss','false'],['insertparagraph','']]); document.queryCommandState('bold')", "true");
    try harness.expectEval(page, "runCommands('<div>abc<b>[def]</b></div>', [['stylewithcss','false'],['insertparagraph',''],['inserttext','d']]); hostHTML() + '|' + document.queryCommandState('bold')", "<div>abc</div><div><b>d</b></div>|true");
    try harness.expectEval(page, "runCommands('<div>abc<b>[def]</b></div>', [['stylewithcss','false'],['delete',''],['insertparagraph',''],['inserttext','d']]); hostHTML() + '|' + document.queryCommandState('bold')", "<div>abc</div><div><b>d</b></div>|true");
    // Nothing deleted, nothing carried: the caret's own style decides.
    try harness.expectEval(page, "runCommands('<div><b>abc</b>[]def</div>', [['stylewithcss','false'],['insertparagraph',''],['inserttext','x']]); hostHTML()", "<div><b>abc</b></div><div>xdef</div>");
}

test "insertParagraph keeps the style of the text it deletes" {
    try helpers.onFreshThread(typingStyleAcrossTheSplit);
}
