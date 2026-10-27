//! Lane editing3, unit 1: the Editing spec's inline formatting commands
//! (specs/w3c/execCommand.md, "Inline formatting commands"):
//! src/html/execcommand/inline.zig through document.execCommand and the
//! queryCommand* methods.
//!
//! Each case is the WPT editing data format (tests/wpt/editing/data/*.js):
//! the editing host's innerHTML with the selection marked by [ ] (in text)
//! or { } (around nodes), the commands, and the expected innerHTML (markers
//! stripped, style attributes normalized as the harness's
//! normalizeSerializedStyle does). The page carries the WPT editing
//! reset.css rules the expectations assume.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

const setup_script =
    \\document.body.innerHTML = '<div contenteditable id=host></div>';
    \\const reset = document.createElement('style');
    \\reset.textContent = 'body { font-family: serif } b, strong { font-weight: bold } .bold { font-weight: bold } .notbold { font-weight: normal } #purple { color: purple } dfn { font-style: italic } :link, :visited { color: blue }';
    \\document.head.appendChild(reset);
    \\globalThis.setupHost = (markup) => {
    \\  const host = document.getElementById('host');
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
    \\  range.setEnd(e, eo);
    \\  if (range.collapsed) range.setEnd(s, so);
    \\  getSelection().removeAllRanges();
    \\  getSelection().addRange(range);
    \\  return host;
    \\};
    \\globalThis.hostHTML = () => {
    \\  const host = document.getElementById('host');
    \\  for (const node of host.querySelectorAll('[style]')) {
    \\    node.setAttribute('style', node.getAttribute('style').replace(/; ?$/, '').replace(/: /g, ':'));
    \\  }
    \\  return host.innerHTML;
    \\};
    \\globalThis.queries = (command) => [document.queryCommandIndeterm(command), document.queryCommandState(command), document.queryCommandValue(command)].join(',');
;

const Case = struct {
    input: []const u8,
    /// JSON array of [command, value] pairs, as the data files write them.
    commands: []const u8,
    expected: []const u8,
    /// The command whose queries are checked, with the indeterm, state and
    /// value before and after ("false,false," style), or null.
    query: ?[]const u8 = null,
    before: []const u8 = "",
    after: []const u8 = "",
};

// From tests/wpt/editing/data/{bold,italic,underline,strikethrough,
// subscript,superscript,fontname,fontsize,forecolor,hilitecolor,backcolor,
// createlink,unlink,removeformat}.js. Underline and strikethrough read
// text-decoration, which the css layer gains with Codex row 124; their
// cases here avoid it.
const cases = [_]Case{
    // bold
    .{ .input = "foo[]bar", .commands = "[[\"bold\",\"\"]]", .expected = "foobar", .query = "bold", .before = "false,false,", .after = "false,true," },
    .{ .input = "<p>[foo</p> <p>bar]</p>", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "<p><b>foo</b></p> <p><b>bar</b></p>", .query = "bold", .before = "false,false,", .after = "false,true," },
    .{ .input = "<p>[foo</p> <p>bar]</p>", .commands = "[[\"stylewithcss\",\"true\"],[\"bold\",\"\"]]", .expected = "<p><span style=\"font-weight:bold\">foo</span></p> <p><span style=\"font-weight:bold\">bar</span></p>" },
    .{ .input = "<span>[foo</span> <span>bar]</span>", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "<b><span>foo</span> <span>bar</span></b>" },
    .{ .input = "<b>foo[]bar</b>", .commands = "[[\"bold\",\"\"]]", .expected = "<b>foobar</b>", .query = "bold", .before = "false,true,", .after = "false,false," },
    .{ .input = "foo<b>[bar]</b>baz", .commands = "[[\"bold\",\"\"]]", .expected = "foobarbaz", .query = "bold", .before = "false,true,", .after = "false,false," },
    .{ .input = "foo<b>b[a]r</b>baz", .commands = "[[\"bold\",\"\"]]", .expected = "foo<b>b</b>a<b>r</b>baz" },
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "foo<b>bar</b>baz", .query = "bold", .before = "false,false,", .after = "false,true," },
    .{ .input = "foo[b<b>ar]</b>baz", .commands = "[[\"bold\",\"\"]]", .expected = "foo<b>bar</b>baz", .query = "bold", .before = "true,false,", .after = "false,true," },
    .{ .input = "<b>foo</b>[bar]<b>baz</b>", .commands = "[[\"bold\",\"\"]]", .expected = "<b>foobarbaz</b>" },
    .{ .input = "<span style=\"font-weight: bold\">[foo]</span>", .commands = "[[\"bold\",\"\"]]", .expected = "foo" },
    // The browsers merge only into the element they would create
    // (bold.html; all three).
    .{ .input = "foo<strong>bar</strong>[baz]", .commands = "[[\"bold\",\"\"]]", .expected = "foo<strong>bar</strong><b>baz</b>" },
    .{ .input = "<strong>foo</strong>[bar]<strong>baz</strong>", .commands = "[[\"bold\",\"\"]]", .expected = "<strong>foo</strong><b>bar</b><strong>baz</strong>" },
    .{ .input = "<b>foo</b>[bar]<b>baz</b>", .commands = "[[\"stylewithcss\",\"true\"],[\"bold\",\"\"]]", .expected = "<b>foo</b><span style=\"font-weight:bold\">bar</span><b>baz</b>" },
    // An element holding the whole range keeps the new style inside it
    // (bold.html ?3001-last; all three).
    .{ .input = "abc<i>[def]</i>ghi", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "abc<i><b>def</b></i>ghi" },
    .{ .input = "abc<i>{def}</i>ghi", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "abc<i><b>def</b></i>ghi" },
    // italic
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"false\"],[\"italic\",\"\"]]", .expected = "foo<i>bar</i>baz", .query = "italic", .before = "false,false,", .after = "false,true," },
    .{ .input = "<i>foo[bar]baz</i>", .commands = "[[\"italic\",\"\"]]", .expected = "<i>foo</i>bar<i>baz</i>" },
    // subscript / superscript
    .{ .input = "foo[bar]baz", .commands = "[[\"subscript\",\"\"]]", .expected = "foo<sub>bar</sub>baz", .query = "subscript", .before = "false,false,", .after = "false,true," },
    .{ .input = "foo<sup>[bar]</sup>baz", .commands = "[[\"subscript\",\"\"]]", .expected = "foo<sub>bar</sub>baz", .query = "superscript", .before = "false,true,", .after = "false,false," },
    .{ .input = "foo[bar]baz", .commands = "[[\"superscript\",\"\"]]", .expected = "foo<sup>bar</sup>baz" },
    // fontName
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"true\"],[\"fontname\",\"sans-serif\"]]", .expected = "foo<span style=\"font-family:sans-serif\">bar</span>baz" },
    // fontSize
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"true\"],[\"fontsize\",\"4\"]]", .expected = "foo<span style=\"font-size:large\">bar</span>baz" },
    .{ .input = "foo[bar]baz", .commands = "[[\"fontsize\",\"2em\"]]", .expected = "foo<font size=\"2\">bar</font>baz" },
    .{ .input = "foo[bar]baz", .commands = "[[\"fontsize\",\"xx-large\"]]", .expected = "foobarbaz" },
    .{ .input = "foo[bar]baz", .commands = "[[\"forecolor\",\"potato quiche\"]]", .expected = "foobarbaz" },
    // foreColor
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"true\"],[\"forecolor\",\"#0000FF\"]]", .expected = "foo<span style=\"color:rgb(0, 0, 255)\">bar</span>baz" },
    .{ .input = "foo[bar]baz", .commands = "[[\"forecolor\",\"currentColor\"]]", .expected = "foobarbaz" },
    // hiliteColor and backColor: a span with background-color, CSS mode or not
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"false\"],[\"hilitecolor\",\"#00FFFF\"]]", .expected = "foo<span style=\"background-color:rgb(0, 255, 255)\">bar</span>baz", .query = "hilitecolor", .before = "false,false,rgba(0, 0, 0, 0)", .after = "false,false,rgb(0, 255, 255)" },
    .{ .input = "foo[bar]baz", .commands = "[[\"backcolor\",\"#00FFFF\"]]", .expected = "foo<span style=\"background-color:rgb(0, 255, 255)\">bar</span>baz" },
    // createLink and unlink
    .{ .input = "foo[bar]baz", .commands = "[[\"createlink\",\"http://www.google.com/\"]]", .expected = "foo<a href=\"http://www.google.com/\">bar</a>baz" },
    .{ .input = "<a href=http://www.google.com/>foo[bar]baz</a>", .commands = "[[\"createlink\",\"http://www.google.com/\"]]", .expected = "<a href=\"http://www.google.com/\">foobarbaz</a>" },
    .{ .input = "foo[bar]baz", .commands = "[[\"createlink\",\"\"]]", .expected = "foobarbaz" },
    .{ .input = "<a href=http://www.google.com/>foo[bar]baz</a>", .commands = "[[\"unlink\",\"\"]]", .expected = "foobarbaz" },
    // removeFormat
    .{ .input = "foo[<b>bar</b>]baz", .commands = "[[\"removeformat\",\"\"]]", .expected = "foobarbaz" },
    .{ .input = "<b>foo[bar]baz</b>", .commands = "[[\"removeformat\",\"\"]]", .expected = "<b>foo</b>bar<b>baz</b>" },
    .{ .input = "foo<span style=\"color: blue\">[bar]</span>baz", .commands = "[[\"removeformat\",\"\"]]", .expected = "foobarbaz" },
};

/// Cases whose <font> must carry its presentational hint (HTML 15.3.4):
/// without it the new font's effective command value is not the new value
/// and force the value step 17 adds a style declaration as well.
const font_cases = [_]Case{
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"false\"],[\"fontname\",\"sans-serif\"]]", .expected = "foo<font face=\"sans-serif\">bar</font>baz", .query = "fontname", .before = "false,false,serif", .after = "false,false,sans-serif" },
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"false\"],[\"fontsize\",\"4\"]]", .expected = "foo<font size=\"4\">bar</font>baz", .query = "fontsize", .before = "false,false,3", .after = "false,false,4" },
    .{ .input = "foo[bar]baz", .commands = "[[\"fontsize\",\"7\"]]", .expected = "foo<font size=\"7\">bar</font>baz" },
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"false\"],[\"forecolor\",\"#0000FF\"]]", .expected = "foo<font color=\"#0000ff\">bar</font>baz", .query = "forecolor", .before = "false,false,rgb(0, 0, 0)", .after = "false,false,rgb(0, 0, 255)" },
    .{ .input = "foo[bar]baz", .commands = "[[\"forecolor\",\"0000FF\"]]", .expected = "foo<font color=\"#0000ff\">bar</font>baz" },
    .{ .input = "<font size=4>[foo]</font>", .commands = "[[\"fontsize\",\"4\"]]", .expected = "<font size=\"4\">foo</font>", .query = "fontsize", .before = "false,false,4", .after = "false,false,4" },
    .{ .input = "<font color=blue>[foo]</font>", .commands = "[[\"forecolor\",\"#0000FF\"]]", .expected = "<font color=\"#0000ff\">foo</font>", .query = "forecolor", .before = "false,false,rgb(0, 0, 255)", .after = "false,false,rgb(0, 0, 255)" },
    .{ .input = "<font face=monospace>[foo]</font>", .commands = "[[\"fontname\",\"sans-serif\"]]", .expected = "<font face=\"sans-serif\">foo</font>", .query = "fontname", .before = "false,false,monospace", .after = "false,false,sans-serif" },
};

fn expectEqual(name: []const u8, case: Case, expected: []const u8, actual: []const u8) bool {
    if (std.mem.eql(u8, expected, actual)) return true;
    std.debug.print("{s} {s} on {s}: expected {s}, got {s}\n", .{ case.commands, name, case.input, expected, actual });
    return false;
}

fn runCases(list: []const Case) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    var failures: usize = 0;
    for (list) |case| {
        const setup = try std.fmt.allocPrint(std.testing.allocator, "document.execCommand('styleWithCSS', false, 'false'); setupHost({f});", .{std.json.fmt(case.input, .{})});
        defer std.testing.allocator.free(setup);
        try page.run(setup);
        if (case.query) |command| {
            const source = try std.fmt.allocPrint(std.testing.allocator, "queries({f})", .{std.json.fmt(command, .{})});
            defer std.testing.allocator.free(source);
            const before = try page.evaluate(source);
            defer std.testing.allocator.free(before);
            if (!expectEqual("queries before", case, case.before, before)) failures += 1;
        }
        const run = try std.fmt.allocPrint(std.testing.allocator, "for (const [c, v] of {s}) document.execCommand(c, false, v);", .{case.commands});
        defer std.testing.allocator.free(run);
        try page.run(run);
        if (case.query) |command| {
            const source = try std.fmt.allocPrint(std.testing.allocator, "queries({f})", .{std.json.fmt(command, .{})});
            defer std.testing.allocator.free(source);
            const after = try page.evaluate(source);
            defer std.testing.allocator.free(after);
            if (!expectEqual("queries after", case, case.after, after)) failures += 1;
        }
        const html = try page.evaluate("hostHTML()");
        defer std.testing.allocator.free(html);
        if (!expectEqual("innerHTML", case, case.expected, html)) failures += 1;
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

fn commandCases() !void {
    try runCases(&cases);
}

test "inline formatting commands: the editing spec's actions and queries" {
    try helpers.onFreshThread(commandCases);
}

fn fontCases() !void {
    try runCases(&font_cases);
}

test "inline formatting commands: <font> carries its presentational hints" {
    try helpers.onFreshThread(fontCases);
}

fn plaintextOnlyDisables() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // "This command must not be enabled if the editing host is in the
    // plaintext-only state" (editing/plaintext-only/styling-commands.html).
    try page.run("host.setAttribute('contenteditable', 'plaintext-only'); setupHost('a[b]c');");
    const enabled = try page.evaluate("['bold','italic','fontName','foreColor','createLink','removeFormat','unlink'].map((c) => document.queryCommandEnabled(c)).join(',')");
    defer std.testing.allocator.free(enabled);
    try std.testing.expectEqualStrings("false,false,false,false,false,false,false", enabled);
    const returned = try page.evaluate("document.execCommand('bold')");
    defer std.testing.allocator.free(returned);
    try std.testing.expectEqualStrings("false", returned);
    const html = try page.evaluate("host.innerHTML");
    defer std.testing.allocator.free(html);
    try std.testing.expectEqualStrings("abc", html);
    // delete stays enabled there.
    const delete_enabled = try page.evaluate("document.queryCommandEnabled('delete')");
    defer std.testing.allocator.free(delete_enabled);
    try std.testing.expectEqualStrings("true", delete_enabled);
}

test "inline formatting commands are disabled in a plaintext-only editing host" {
    try helpers.onFreshThread(plaintextOnlyDisables);
}

fn inputEventTypes() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // execCommand fires input (never beforeinput) with the browsers'
    // inputType (input-events/input-events-exec-command.html).
    try page.run("globalThis.seen = []; host.addEventListener('input', (e) => seen.push(e.inputType)); host.addEventListener('beforeinput', (e) => seen.push('before:' + e.inputType));");
    try page.run("for (const c of ['bold', 'italic', 'underline', 'strikeThrough', 'subscript', 'superscript', 'removeFormat']) { setupHost('a[b]c'); document.execCommand(c); }");
    const seen = try page.evaluate("seen.join(',')");
    defer std.testing.allocator.free(seen);
    try std.testing.expectEqualStrings("formatBold,formatItalic,formatUnderline,formatStrikeThrough,formatSubscript,formatSuperscript,formatRemove", seen);
}

test "inline formatting commands fire input with the browsers' inputType" {
    try helpers.onFreshThread(inputEventTypes);
}
