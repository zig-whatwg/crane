//! Lane editing2, unit 2 (batch 1b): joining blocks whose white-space
//! differs keeps the moved line's white-space - Gecko's
//! MoveNodeOrChildrenWithTransaction (editor/libeditor/
//! HTMLEditorDeleteHandler.cpp): an element gets `white-space` in its style
//! attribute, a Text node a new <span style="white-space: v">. Expected
//! results are the first accepted entry of
//! editing/other/join-different-white-space-style-*.html and
//! join-pre-and-other-block.html, normalized as their
//! normalizeStyleAttributeValues() does.
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

const setup_script =
    \\document.body.innerHTML = '<div contenteditable id=host></div>';
    \\const sheet = document.createElement('style');
    \\sheet.textContent = '.pre { white-space: pre } .preWrap { white-space: pre-wrap } .preLine { white-space: pre-line } .nowrap { white-space: nowrap }';
    \\document.head.appendChild(sheet);
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
    \\    if ((i = d.indexOf(']')) !== -1) { d = d.slice(0, i) + d.slice(i + 1); e = t; eo = i; }
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
    \\  getSelection().removeAllRanges();
    \\  getSelection().addRange(range);
    \\  return host;
    \\};
    \\globalThis.hostHTML = () => {
    \\  const host = document.getElementById('host');
    \\  for (const el of host.querySelectorAll('[style]')) el.setAttribute('style', el.getAttribute('style').replace(/; ?$/, '').replace(/: /g, ':'));
    \\  return host.innerHTML;
    \\};
;

const values = [_][]const u8{ "normal", "pre", "pre-wrap", "pre-line", "nowrap" };

fn preservesLineBreaks(value: []const u8) bool {
    return std.mem.eql(u8, value, "pre") or std.mem.eql(u8, value, "pre-wrap") or std.mem.eql(u8, value, "pre-line");
}

fn className(value: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, value, "pre")) return "pre";
    if (std.mem.eql(u8, value, "pre-wrap")) return "preWrap";
    if (std.mem.eql(u8, value, "pre-line")) return "preLine";
    if (std.mem.eql(u8, value, "nowrap")) return "nowrap";
    return null;
}

const Runner = struct {
    page: helpers.Page,
    allocator: std.mem.Allocator,
    failures: usize = 0,
    cases: usize = 0,

    fn check(self: *Runner, command: []const u8, input: []const u8, expected: []const u8) !void {
        self.cases += 1;
        const source = try std.fmt.allocPrint(self.allocator, "setupHost({f}); document.execCommand({f}, false, ''); hostHTML()", .{ std.json.fmt(input, .{}), std.json.fmt(command, .{}) });
        defer self.allocator.free(source);
        const actual = try self.page.evaluate(source);
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, expected)) {
            self.failures += 1;
            if (self.failures <= 40) std.debug.print("{s} at {s}:\n  expected {s}\n  got      {s}\n", .{ command, input, expected, actual });
        }
    }
};

/// The two directions of one case: delete with the caret at the start of
/// the right block, forwardDelete with it at the end of the left one.
fn both(r: *Runner, left_open: []const u8, left_text: []const u8, middle: []const u8, right_open: []const u8, right_rest: []const u8, expected: []const u8) !void {
    const a = r.allocator;
    const backward = try std.fmt.allocPrint(a, "{s}{s}{s}{s}[]{s}", .{ left_open, left_text, middle, right_open, right_rest });
    defer a.free(backward);
    try r.check("delete", backward, expected);
    const forward = try std.fmt.allocPrint(a, "{s}{s}[]{s}{s}{s}", .{ left_open, left_text, middle, right_open, right_rest });
    defer a.free(forward);
    try r.check("forwardDelete", forward, expected);
}

fn paragraphs(r: *Runner) !void {
    const a = r.allocator;
    for (values) |left| for (values) |right| {
        if (std.mem.eql(u8, left, right)) continue;
        const l = try std.fmt.allocPrint(a, "<div style=\"white-space:{s}\">", .{left});
        defer a.free(l);
        const rs = try std.fmt.allocPrint(a, "style=\"white-space:{s}\"", .{right});
        defer a.free(rs);
        const rdiv = try std.fmt.allocPrint(a, "<div {s}>", .{rs});
        defer a.free(rdiv);
        for ([_][]const u8{ "", "\n" }) |between| {
            const middle = try std.fmt.allocPrint(a, "</div>{s}", .{between});
            defer a.free(middle);
            // A text line: a new span.
            var expected = try std.fmt.allocPrint(a, "{s}abc<span {s}>def</span></div>", .{ l, rs });
            try both(r, l, "abc", middle, rdiv, "def</div>", expected);
            a.free(expected);
            // A br ends the line; the rest stays.
            expected = try std.fmt.allocPrint(a, "{s}abc<span {s}>def</span></div>{s}ghi</div>", .{ l, rs, rdiv });
            try both(r, l, "abc", middle, rdiv, "def<br>ghi</div>", expected);
            a.free(expected);
            // An inline: its own style attribute, split at the line's end.
            expected = try std.fmt.allocPrint(a, "{s}abc<b {s}>def</b></div>{s}<b>ghi</b></div>", .{ l, rs, rdiv });
            try both(r, l, "abc", middle, try std.fmt.allocPrint(a, "{s}<b>", .{rdiv}), "def<br>ghi</b></div>", expected);
            a.free(expected);
            // An inline, then text: one each.
            expected = try std.fmt.allocPrint(a, "{s}abc<b {s}>def</b><span {s}>ghi</span></div>{s}jkl</div>", .{ l, rs, rs, rdiv });
            try both(r, l, "abc", middle, try std.fmt.allocPrint(a, "{s}<b>", .{rdiv}), "def</b>ghi<br>jkl</div>", expected);
            a.free(expected);
            // A br at the end of the inline.
            expected = try std.fmt.allocPrint(a, "{s}abc<b {s}>def</b></div>{s}ghi</div>", .{ l, rs, rdiv });
            try both(r, l, "abc", middle, try std.fmt.allocPrint(a, "{s}<b>", .{rdiv}), "def<br></b>ghi</div>", expected);
            a.free(expected);
            // A nested block's line.
            expected = try std.fmt.allocPrint(a, "{s}abc<span {s}>def</span></div>{s}ghi</div>", .{ l, rs, rdiv });
            try both(r, l, "abc", middle, try std.fmt.allocPrint(a, "{s}<div>", .{rdiv}), "def</div>ghi</div>", expected);
            a.free(expected);
            if (preservesLineBreaks(right)) {
                // A preserved line feed ends the line, in text and in an inline.
                expected = try std.fmt.allocPrint(a, "{s}abc<span {s}>def</span></div>{s}ghi</div>", .{ l, rs, rdiv });
                try both(r, l, "abc", middle, rdiv, "def\nghi</div>", expected);
                a.free(expected);
                expected = try std.fmt.allocPrint(a, "{s}abc<b {s}>def</b></div>{s}<b>ghi</b></div>", .{ l, rs, rdiv });
                try both(r, l, "abc", middle, try std.fmt.allocPrint(a, "{s}<b>", .{rdiv}), "def\nghi</b></div>", expected);
                a.free(expected);
                expected = try std.fmt.allocPrint(a, "{s}abc<b {s}>def</b></div>{s}ghi</div>", .{ l, rs, rdiv });
                try both(r, l, "abc", middle, try std.fmt.allocPrint(a, "{s}<b>", .{rdiv}), "def\n</b>ghi</div>", expected);
                a.free(expected);
            }
            // The class form of the right block.
            if (className(right)) |class| {
                const cdiv = try std.fmt.allocPrint(a, "<div class=\"{s}\">", .{class});
                defer a.free(cdiv);
                expected = try std.fmt.allocPrint(a, "{s}abc<span {s}>def</span></div>{s}ghi</div>", .{ l, rs, cdiv });
                try both(r, l, "abc", middle, cdiv, "def<br>ghi</div>", expected);
                a.free(expected);
            }
        }
    };
}

fn lines(r: *Runner) !void {
    const a = r.allocator;
    for (values) |right| {
        if (std.mem.eql(u8, right, "normal")) continue;
        // A line in the (normal) editing host, then a paragraph.
        const rdiv = try std.fmt.allocPrint(a, "<div style=\"white-space:{s}\">", .{right});
        defer a.free(rdiv);
        const expected = try std.fmt.allocPrint(a, "abc<span style=\"white-space:{s}\">def</span>{s}ghi</div>", .{ right, rdiv });
        defer a.free(expected);
        try both(r, "", "abc", "", rdiv, "def<br>ghi</div>", expected);
    }
    for (values) |left| {
        if (std.mem.eql(u8, left, "normal")) continue;
        // A paragraph, then a line in the (normal) editing host.
        const ldiv = try std.fmt.allocPrint(a, "<div style=\"white-space:{s}\">", .{left});
        defer a.free(ldiv);
        const expected = try std.fmt.allocPrint(a, "{s}abc<span style=\"white-space:normal\">def</span></div>ghi", .{ldiv});
        defer a.free(expected);
        try both(r, ldiv, "abc", "</div>", "", "def<br>ghi", expected);
    }
    // The same white-space on both sides: nothing to keep.
    try both(r, "<div style=\"white-space:pre\">", "abc", "</div>", "<div style=\"white-space:pre\">", "def</div>", "<div style=\"white-space:pre\">abcdef</div>");
    try both(r, "", "abc", "", "<div style=\"white-space:normal\">", "def<br>ghi</div>", "abcdef<div style=\"white-space:normal\">ghi</div>");
}

fn preBlocks(r: *Runner) !void {
    // A <pre> styled by the UA sheet alone keeps nothing, either way.
    try both(r, "<div>", "abc", "</div>", "<pre>", "def</pre>", "<div>abcdef</div>");
    try both(r, "<div>", "abc", "</div>", "<pre>", "def\nghi</pre>", "<div>abcdef</div><pre>ghi</pre>");
    try both(r, "<pre>", "abc", "</pre>", "<div>", "def<br>ghi</div>", "<pre>abcdef</pre><div>ghi</div>");
    // An author `pre { white-space: pre }`: the moved line keeps it.
    try r.page.run("const preRule = document.createElement('style'); preRule.id = 'preRule'; preRule.textContent = 'pre { white-space: pre }'; document.head.appendChild(preRule);");
    try both(r, "<div>", "abc", "</div>", "<pre>", "def</pre>", "<div>abc<span style=\"white-space:pre\">def</span></div>");
    try both(r, "<div>", "abc", "</div>", "<pre><b>", "def\nghi</b></pre>", "<div>abc<b style=\"white-space:pre\">def</b></div><pre><b>ghi</b></pre>");
    try r.page.run("document.getElementById('preRule').remove();");
    // A style attribute on the pre is an author declaration too.
    try both(r, "<div>", "abc", "</div>", "<pre style=\"white-space:pre\">", "def</pre>", "<div>abc<span style=\"white-space:pre\">def</span></div>");
}

fn whiteSpaceJoins() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    // The case strings live in an arena over the testing allocator, freed
    // with it.
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var r: Runner = .{ .page = page, .allocator = arena.allocator() };
    try paragraphs(&r);
    try lines(&r);
    try preBlocks(&r);
    if (r.failures != 0) std.debug.print("{d} of {d} cases failed\n", .{ r.failures, r.cases });
    try std.testing.expectEqual(@as(usize, 0), r.failures);
}

test "joining blocks keeps the moved line's white-space" {
    try helpers.onFreshThread(whiteSpaceJoins);
}

fn pressBackspace(page: helpers.Page) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, .{ .key = "Backspace", .code = "Backspace", .key_code = 8 }, .{});
    html.user_input.keyUp(&keyboard, document, .{ .key = "Backspace", .code = "Backspace", .key_code = 8 }, .{});
}

fn backspaceKeepsIt() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    try page.run("setupHost('<div>abc</div><div class=\"pre\">[]def\\nghi</div>').focus();");
    pressBackspace(page);
    const actual = try page.evaluate("hostHTML()");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings("<div>abc<span style=\"white-space:pre\">def</span></div><div class=\"pre\">ghi</div>", actual);
}

test "Backspace joins with the white-space kept" {
    try helpers.onFreshThread(backspaceKeepsIt);
}
