//! Shared by lane editing4's tests (editing4_*_test.zig): the WPT editing
//! data format - an editing host's innerHTML with the selection marked by
//! [ ] (in text) or { } (around nodes), a list of commands, and the
//! expected innerHTML - run on a page of its own on a fresh thread.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

/// The page's script-side harness (lane editing1's, with a command list).
pub const setup_script =
    \\document.body.innerHTML = '<div contenteditable id=host></div><p>test</p>';
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
    \\globalThis.hostHTML = () => document.getElementById('host').innerHTML;
    \\globalThis.runCommands = (markup, commands) => {
    \\  setupHost(markup);
    \\  const returned = commands.map(([name, value]) => String(document.execCommand(name, false, value)));
    \\  return returned.join(',');
    \\};
;

/// One WPT-format case: the commands run in order, each [name, value].
pub const Case = struct {
    input: []const u8,
    commands: []const [2][]const u8,
    expected: []const u8,
};

/// Run `cases` on one page; every mismatch is printed, and any fails the
/// test.
pub fn runCases(page: helpers.Page, cases: []const Case) !void {
    var failures: usize = 0;
    for (cases) |case| {
        var list: std.ArrayList(u8) = .empty;
        defer list.deinit(std.testing.allocator);
        try list.appendSlice(std.testing.allocator, "[");
        for (case.commands, 0..) |command, i| {
            if (i > 0) try list.appendSlice(std.testing.allocator, ",");
            try list.print(std.testing.allocator, "[{f},{f}]", .{ std.json.fmt(command[0], .{}), std.json.fmt(command[1], .{}) });
        }
        try list.appendSlice(std.testing.allocator, "]");
        const source = try std.fmt.allocPrint(std.testing.allocator, "runCommands({f}, {s})", .{ std.json.fmt(case.input, .{}), list.items });
        defer std.testing.allocator.free(source);
        const returned = try page.evaluate(source);
        defer std.testing.allocator.free(returned);
        const actual = try page.evaluate("hostHTML()");
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) {
            std.debug.print("{s} on {s}: expected {s}, got {s} (returned {s})\n", .{ list.items, case.input, case.expected, actual, returned });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

/// The value of a script expression, OWNED by std.testing.allocator.
pub fn evaluate(page: helpers.Page, source: []const u8) ![]u8 {
    return page.evaluate(source);
}

/// Expect `source` to evaluate to `expected`.
pub fn expectEval(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    if (!std.mem.eql(u8, actual, expected)) {
        std.debug.print("{s}: expected {s}, got {s}\n", .{ source, expected, actual });
        return error.TestUnexpectedResult;
    }
}
