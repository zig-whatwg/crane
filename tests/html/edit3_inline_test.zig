//! Lane edit3: push down values in CSS mode (styleWithCSS true) keeps the
//! existing b, i, u or strike element, or the styled span, on the parts
//! around the node instead of making the Editing spec's new styled spans -
//! the user's ruling (b) of 2026-11-19 5:48 PM ET, "Follow all three
//! browsers" (src/html/execcommand/inline.zig pushDownValues).
//!
//! Each case is the WPT editing data format (tests/wpt/editing/data/*.js),
//! as tests/html/edit2_inline_test.zig runs it: the editing host's innerHTML
//! with the selection marked by [ ] (in text) or { } (around nodes), the
//! commands, and the expected innerHTML (markers stripped, style attributes
//! normalized as the harness's normalizeSerializedStyle does). The expected
//! values are what Chrome 157, Firefox 160 and Safari 27.2 produce (wpt.fyi
//! aligned runs at 2358bd4835), unless a comment names fewer.
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

const css = "[\"stylewithcss\",\"true\"]";

const css_push_down_cases = [_]Case{
    // bold.html ?2001-3000, italic.html ?1-1000 / ?1001-2000, underline.html
    // ?1-1000 / ?1001-2000, strikethrough.html ?1-1000 (FFF: the data keeps
    // the spec's spans; ruling (b) losses).
    .{ .input = "foo[<b>b]ar</b>baz", .commands = "[" ++ css ++ ",[\"bold\",\"\"]]", .expected = "foob<b>ar</b>baz" },
    .{ .input = "foo<b>ba[r</b>]baz", .commands = "[" ++ css ++ ",[\"bold\",\"\"]]", .expected = "foo<b>ba</b>rbaz" },
    .{ .input = "foo<i>b[a]r</i>baz", .commands = "[" ++ css ++ ",[\"italic\",\"\"]]", .expected = "foo<i>b</i>a<i>r</i>baz" },
    .{ .input = "<strike>foo[bar]baz</strike>", .commands = "[" ++ css ++ ",[\"strikethrough\",\"\"]]", .expected = "<strike>foo</strike>bar<strike>baz</strike>" },
    .{ .input = "<u>foo[bar]baz</u>", .commands = "[" ++ css ++ ",[\"underline\",\"\"]]", .expected = "<u>foo</u>bar<u>baz</u>" },
    .{ .input = "foo[<u>b]ar</u>baz", .commands = "[" ++ css ++ ",[\"underline\",\"\"]]", .expected = "foob<u>ar</u>baz" },
    // A styled span and a styled u: the parts around the node keep the
    // element as it was, the node's part loses the value (Firefox and Safari;
    // Chrome writes text-decoration-line on the middle part).
    .{ .input = "foo<u style=\"text-decoration: line-through\">b[a]r</u>baz", .commands = "[" ++ css ++ ",[\"strikethrough\",\"\"]]", .expected = "foo<u style=\"text-decoration:line-through\">b</u><u>a</u><u style=\"text-decoration:line-through\">r</u>baz" },
    .{ .input = "foo<span style=\"text-decoration: underline line-through\">b[a]r</span>baz", .commands = "[" ++ css ++ ",[\"strikethrough\",\"\"]]", .expected = "foo<span style=\"text-decoration:underline line-through\">b</span><span style=\"text-decoration:underline\">a</span><span style=\"text-decoration:underline line-through\">r</span>baz" },
    // PPP rows Crane fails today (strikethrough.html ?2001-last,
    // underline.html ?1001-2000).
    .{ .input = "<strike>fo[o</strike><s>b]ar</s>", .commands = "[" ++ css ++ ",[\"strikethrough\",\"\"]]", .expected = "<strike>fo</strike>ob<s>ar</s>" },
    .{ .input = "foo<u>ba[r</u>]baz", .commands = "[" ++ css ++ ",[\"underline\",\"\"]]", .expected = "foo<u>ba</u>rbaz" },
    // Outside CSS mode nothing changes: force the value remakes the same
    // element (all three, and the data).
    .{ .input = "foo[<b>b]ar</b>baz", .commands = "[[\"stylewithcss\",\"false\"],[\"bold\",\"\"]]", .expected = "foob<b>ar</b>baz" },
    .{ .input = "<u>foo[bar]baz</u>", .commands = "[[\"stylewithcss\",\"false\"],[\"underline\",\"\"]]", .expected = "<u>foo</u>bar<u>baz</u>" },
    // Not the ruling's elements: a font-weight span applying bold nests, as
    // the spec and Firefox do (the user's ruling (a), 2026-11-19).
    .{ .input = "<span style=\"font-weight: 100\">foo[bar]baz</span>", .commands = "[" ++ css ++ ",[\"bold\",\"\"]]", .expected = "<span style=\"font-weight:100\">foo<span style=\"font-weight:bold\">bar</span>baz</span>" },
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

fn cssPushDownCases() !void {
    try runCases(&css_push_down_cases);
}

test "push down values in CSS mode keeps the b, i, u, strike or styled span on the parts around the node (ruling (b))" {
    try helpers.onFreshThread(cssPushDownCases);
}
