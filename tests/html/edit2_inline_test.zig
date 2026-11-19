//! Lane edit2, group 1: the inline formatting commands where Chrome, Firefox
//! and Safari all differ from the Editing spec's text and the WPT editing
//! data follows them (src/html/execcommand/inline.zig):
//!
//! - strikethrough makes a <strike>, not the spec's <s>;
//! - push down values splits an ancestor whose value differs even when the
//!   value above it is not the new one (the spec's step 10 gives up and
//!   nests the new style inside it);
//! - a <font> or <span> that wraps exactly the node takes the new value
//!   itself instead of gaining a new wrapper.
//!
//! Each case is the WPT editing data format (tests/wpt/editing/data/*.js):
//! the editing host's innerHTML with the selection marked by [ ] (in text)
//! or { } (around nodes), the commands, and the expected innerHTML (markers
//! stripped, style attributes normalized as the harness's
//! normalizeSerializedStyle does). Every case passes in all three browsers
//! (wpt.fyi aligned runs at 2358bd4835: Chrome 157, Firefox 160, Safari
//! 27.2) unless its comment says otherwise.
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
;

const Case = struct {
    input: []const u8,
    /// JSON array of [command, value] pairs, as the data files write them.
    commands: []const u8,
    expected: []const u8,
};

const strike_cases = [_]Case{
    // strikethrough.html: "foo[bar]baz", "<strike>foo[bar]baz</strike>",
    // "fo[o<s>b]ar</s>baz".
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"false\"],[\"strikethrough\",\"\"]]", .expected = "foo<strike>bar</strike>baz" },
    .{ .input = "<strike>foo[bar]baz</strike>", .commands = "[[\"stylewithcss\",\"false\"],[\"strikethrough\",\"\"]]", .expected = "<strike>foo</strike>bar<strike>baz</strike>" },
    .{ .input = "fo[o<s>b]ar</s>baz", .commands = "[[\"strikethrough\",\"\"]]", .expected = "fo<strike>o</strike><s>bar</s>baz" },
    .{ .input = "<u>foo[b<i>ar]ba</i>z</u>", .commands = "[[\"stylewithcss\",\"false\"],[\"strikethrough\",\"\"]]", .expected = "<u>foo<strike>b</strike><i><strike>ar</strike>ba</i>z</u>" },
    // CSS mode still makes a span.
    .{ .input = "foo[bar]baz", .commands = "[[\"stylewithcss\",\"true\"],[\"strikethrough\",\"\"]]", .expected = "foo<span style=\"text-decoration:line-through\">bar</span>baz" },
};

const push_down_cases = [_]Case{
    // fontsize.html ?1001-2000 (the CSS row: Chrome and Safari; Firefox nests).
    .{ .input = "<font size=1>foo[bar]baz</font>", .commands = "[[\"stylewithcss\",\"false\"],[\"fontsize\",\"4\"]]", .expected = "<font size=\"1\">foo</font><font size=\"4\">bar</font><font size=\"1\">baz</font>" },
    .{ .input = "<font size=1>foo[bar]baz</font>", .commands = "[[\"stylewithcss\",\"true\"],[\"fontsize\",\"4\"]]", .expected = "<font size=\"1\">foo</font><span style=\"font-size:large\">bar</span><font size=\"1\">baz</font>" },
    .{ .input = "<span style=\"font-size: xx-small\">foo[bar]baz</span>", .commands = "[[\"stylewithcss\",\"false\"],[\"fontsize\",\"4\"]]", .expected = "<span style=\"font-size:xx-small\">foo</span><font size=\"4\">bar</font><span style=\"font-size:xx-small\">baz</span>" },
    .{ .input = "fo[o<font size=2>b]ar</font>baz", .commands = "[[\"stylewithcss\",\"false\"],[\"fontsize\",\"4\"]]", .expected = "fo<font size=\"4\">ob</font><font size=\"2\">ar</font>baz" },
    .{ .input = "fo[o<font size=2>b]ar</font>baz", .commands = "[[\"stylewithcss\",\"true\"],[\"fontsize\",\"4\"]]", .expected = "fo<span style=\"font-size:large\">ob</span><font size=\"2\">ar</font>baz" },
    .{ .input = "foo<font size=2>ba[r</font>b]az", .commands = "[[\"stylewithcss\",\"false\"],[\"fontsize\",\"4\"]]", .expected = "foo<font size=\"2\">ba</font><font size=\"4\">rb</font>az" },
    .{ .input = "<font size=1>fo[o</font><span style=font-size:xx-small>b]ar</span>", .commands = "[[\"stylewithcss\",\"false\"],[\"fontsize\",\"4\"]]", .expected = "<font size=\"1\">fo</font><font size=\"4\">ob</font><span style=\"font-size:xx-small\">ar</span>" },
    // fontsize.html ?2001-last: the split part keeps the ancestor's other
    // declarations.
    .{ .input = "<span style=\"font-size:32px; background-color:rgb(0, 128, 128)\">a[b]c</span>", .commands = "[[\"styleWithCSS\",\"false\"],[\"fontSize\",\"5\"]]", .expected = "<span style=\"font-size:32px; background-color:rgb(0, 128, 128)\">a</span><span style=\"background-color:rgb(0, 128, 128)\"><font size=\"5\">b</font></span><span style=\"font-size:32px; background-color:rgb(0, 128, 128)\">c</span>" },
    // fontname.html ?1001-2000.
    .{ .input = "foo<span style=\"font-family: monospace\">b[a]r</span>baz", .commands = "[[\"stylewithcss\",\"false\"],[\"fontname\",\"sans-serif\"]]", .expected = "foo<span style=\"font-family:monospace\">b</span><font face=\"sans-serif\">a</font><span style=\"font-family:monospace\">r</span>baz" },
    .{ .input = "foo<span style=\"font-family: monospace\">b[a]r</span>baz", .commands = "[[\"stylewithcss\",\"true\"],[\"fontname\",\"sans-serif\"]]", .expected = "foo<span style=\"font-family:monospace\">b</span><span style=\"font-family:sans-serif\">a</span><span style=\"font-family:monospace\">r</span>baz" },
    // forecolor.html.
    .{ .input = "foo<font color=brown>ba[r</font>b]az", .commands = "[[\"stylewithcss\",\"false\"],[\"forecolor\",\"#0000FF\"]]", .expected = "foo<font color=\"brown\">ba</font><font color=\"#0000ff\">rb</font>az" },
    .{ .input = "foo[<font color=brown>b]ar</font>baz", .commands = "[[\"stylewithcss\",\"true\"],[\"forecolor\",\"#0000FF\"]]", .expected = "foo<span style=\"color:rgb(0, 0, 255)\">b</span><font color=\"brown\">ar</font>baz" },
    // The spec's push down where the value above is the new one stays as it
    // was (bold.html "<b id=purple>bar [baz] qoz</b>": the data keeps the
    // spec's span, which Crane passes).
    .{ .input = "<b id=purple>bar [baz] qoz</b>", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "<span id=\"purple\"><b>bar </b>baz<b> qoz</b></span>" },
    .{ .input = "foo<b>b[a]r</b>baz", .commands = "[[\"bold\",\"\"]]", .expected = "foo<b>b</b>a<b>r</b>baz" },
    // The range's end at its innermost equivalent point is inside the i
    // (bold.html; all three).
    .{ .input = "abc<i>[def</i>]ghi", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "abc<i><b>def</b></i>ghi" },
    .{ .input = "abc[<i>def]</i>ghi", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "abc<i><b>def</b></i>ghi" },
    // Only fontSize, fontName and foreColor split where the spec gives up:
    // bold and the background colors nest (Firefox and the data; Chrome and
    // Safari split), and no browser splits a block.
    .{ .input = "<span style=\"font-weight: 100\">foo[bar]baz</span>", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "<span style=\"font-weight:100\">foo<b>bar</b>baz</span>" },
    .{ .input = "fo[o<span style=background-color:tan>b]ar</span>baz", .commands = "[[\"stylewithcss\",\"true\"],[\"backcolor\",\"#00FFFF\"]]", .expected = "fo<span style=\"background-color:rgb(0, 255, 255)\">o</span><span style=\"background-color:tan\"><span style=\"background-color:rgb(0, 255, 255)\">b</span>ar</span>baz" },
    .{ .input = "<p style=\"font-size: medium\">foo[bar]baz</p>", .commands = "[[\"stylewithcss\",\"false\"],[\"fontsize\",\"4\"]]", .expected = "<p style=\"font-size:medium\">foo<font size=\"4\">bar</font>baz</p>" },
    // A simple modifiable element that push down removes gives its other
    // children copies of itself (all three; strikethrough.html, italic.html).
    .{ .input = "<s>foo[bar]baz</s>", .commands = "[[\"stylewithcss\",\"false\"],[\"strikethrough\",\"\"]]", .expected = "<s>foo</s>bar<s>baz</s>" },
    .{ .input = "<s>foo[bar]baz</s>", .commands = "[[\"stylewithcss\",\"true\"],[\"strikethrough\",\"\"]]", .expected = "<s>foo</s>bar<s>baz</s>" },
    .{ .input = "foo<em>b[a]r</em>baz", .commands = "[[\"stylewithcss\",\"false\"],[\"italic\",\"\"]]", .expected = "foo<em>b</em>a<em>r</em>baz" },
    .{ .input = "foo<em>b[a]r</em>baz", .commands = "[[\"stylewithcss\",\"true\"],[\"italic\",\"\"]]", .expected = "foo<em>b</em>a<em>r</em>baz" },
};

const exact_wrap_cases = [_]Case{
    // fontsize.html, forecolor.html, fontname.html ?2001-last (either
    // attribute order is accepted; Crane appends).
    .{ .input = "<font color=#ff0000>[abc]</font>", .commands = "[[\"styleWithCSS\",\"false\"],[\"fontSize\",\"7\"]]", .expected = "<font color=\"#ff0000\" size=\"7\">abc</font>" },
    .{ .input = "<font size=7>[abc]</font>", .commands = "[[\"styleWithCSS\",\"false\"],[\"foreColor\",\"#ff0000\"]]", .expected = "<font size=\"7\" color=\"#ff0000\">abc</font>" },
    .{ .input = "<font color=#ff0000>[abc]</font>", .commands = "[[\"styleWithCSS\",\"false\"],[\"fontName\",\"monospace\"]]", .expected = "<font color=\"#ff0000\" face=\"monospace\">abc</font>" },
    // hilitecolor.html: the background merges into a style-only span; a
    // font keeps a new span inside (multitest.html's typed fonts need that;
    // the browsers' style on an author's font is not distinguished).
    .{ .input = "<font size=6>[foo]</font>", .commands = "[[\"stylewithcss\",\"false\"],[\"hilitecolor\",\"#00FFFF\"]]", .expected = "<font size=\"6\"><span style=\"background-color:rgb(0, 255, 255)\">foo</span></font>" },
    .{ .input = "<span style=font-size:xx-large>[foo]</span>", .commands = "[[\"stylewithcss\",\"true\"],[\"hilitecolor\",\"#00FFFF\"]]", .expected = "<span style=\"font-size:xx-large; background-color:rgb(0, 255, 255)\">foo</span>" },
    // A node with siblings still gets its own wrapper.
    .{ .input = "<font color=#ff0000>a[b]c</font>", .commands = "[[\"styleWithCSS\",\"false\"],[\"fontSize\",\"7\"]]", .expected = "<font color=\"#ff0000\">a<font size=\"7\">b</font>c</font>" },
};

const decoration_cases = [_]Case{
    // Firefox and Safari.
    .{ .input = "foo<span style=\"text-decoration: underline\">[bar]</span>baz", .commands = "[[\"stylewithcss\",\"true\"],[\"strikethrough\",\"\"]]", .expected = "foo<span style=\"text-decoration:underline line-through\">bar</span>baz" },
    .{ .input = "foo<ins>[bar]</ins>baz", .commands = "[[\"stylewithcss\",\"true\"],[\"strikethrough\",\"\"]]", .expected = "foo<ins style=\"text-decoration:underline line-through\">bar</ins>baz" },
    .{ .input = "foo<del>[bar]</del>baz", .commands = "[[\"stylewithcss\",\"true\"],[\"underline\",\"\"]]", .expected = "foo<del style=\"text-decoration:underline line-through\">bar</del>baz" },
    // All three: the color and style go.
    .{ .input = "abc<span style=\"text-decoration:underline blue dotted\">[def]</span>ghi", .commands = "[[\"stylewithcss\",\"true\"],[\"strikethrough\",\"\"]]", .expected = "abc<span style=\"text-decoration:underline line-through\">def</span>ghi" },
    .{ .input = "abc<span style=\"text-decoration:underline line-through blue dotted\">[def]</span>ghi", .commands = "[[\"stylewithcss\",\"true\"],[\"strikethrough\",\"\"]]", .expected = "abc<span style=\"text-decoration:underline\">def</span>ghi" },
};

const unlink_cases = [_]Case{
    // Chrome and Safari.
    .{ .input = "foo<a href=https://example.com class=bold>[bar]</a>baz", .commands = "[[\"stylewithcss\",\"false\"],[\"unlink\",\"\"]]", .expected = "foobarbaz" },
    .{ .input = "foo<a href=https://example.com style=font-weight:bold>[bar]</a>baz", .commands = "[[\"stylewithcss\",\"false\"],[\"unlink\",\"\"]]", .expected = "foo<b>bar</b>baz" },
    // All three.
    .{ .input = "foo<a href=https://example.com style=font-weight:bold>[bar]</a>baz", .commands = "[[\"stylewithcss\",\"true\"],[\"unlink\",\"\"]]", .expected = "foo<span style=\"font-weight:bold\">bar</span>baz" },
    // An id keeps the spec's a (the data; no browser passes it).
    .{ .input = "foo<a id=foo href=http://www.google.com/>[bar]</a>baz", .commands = "[[\"unlink\",\"\"]]", .expected = "foo<a id=\"foo\">bar</a>baz" },
};

fn runCases(list: []const Case) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    var failures: usize = 0;
    for (list) |case| {
        const setup = try std.fmt.allocPrint(std.testing.allocator, "document.execCommand('styleWithCSS', false, 'false'); setupHost({f});", .{std.json.fmt(case.input, .{})});
        defer std.testing.allocator.free(setup);
        try page.run(setup);
        const run = try std.fmt.allocPrint(std.testing.allocator, "for (const [c, v] of {s}) document.execCommand(c, false, v);", .{case.commands});
        defer std.testing.allocator.free(run);
        try page.run(run);
        const html = try page.evaluate("hostHTML()");
        defer std.testing.allocator.free(html);
        if (!std.mem.eql(u8, case.expected, html)) {
            std.debug.print("{s} on {s}: expected {s}, got {s}\n", .{ case.commands, case.input, case.expected, html });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

fn strikeCases() !void {
    try runCases(&strike_cases);
}

test "strikethrough makes a <strike> element, as every browser does" {
    try helpers.onFreshThread(strikeCases);
}

fn pushDownCases() !void {
    try runCases(&push_down_cases);
}

test "push down values splits a differing ancestor, as every browser does" {
    try helpers.onFreshThread(pushDownCases);
}

fn exactWrapCases() !void {
    try runCases(&exact_wrap_cases);
}

test "a <font> or <span> wrapping exactly the node takes the new value" {
    try helpers.onFreshThread(exactWrapCases);
}

fn decorationCases() !void {
    try runCases(&decoration_cases);
}

test "strikethrough and underline in CSS mode join the wrapper's text-decoration" {
    try helpers.onFreshThread(decorationCases);
}

fn unlinkCases() !void {
    try runCases(&unlink_cases);
}

test "unlink removes a link with only class or style beside its href, as Chrome and Safari do" {
    try helpers.onFreshThread(unlinkCases);
}
