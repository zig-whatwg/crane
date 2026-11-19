//! Lane edit2, group 2: formatBlock as the browsers do it
//! (src/html/execcommand/block.zig):
//!
//! - queryCommandValue("formatBlock") reads the selection's VISIBLE range
//!   (Blink's ValueFormatBlock over the VisibleSelection), and a block that
//!   holds other blocks is the value too;
//! - a dd or dt line gets a dl around it;
//! - xmp and listing are wrapped whole, not replaced;
//! - a line already inside a block of the asked name is left alone only
//!   when that block is its own nearest one.
//!
//! The cases are the WPT editing data format (tests/wpt/editing/data/
//! formatblock.js); each passes in Chrome 157, Firefox 160 and Safari 27.2
//! (wpt.fyi aligned runs at 2358bd4835) unless its comment says otherwise.
const std = @import("std");
const harness = @import("editing4_harness.zig");
const helpers = @import("edges_node_holders_helpers.zig");

const value_script =
    \\globalThis.formatBlockValues = (markup, commands) => {
    \\  setupHost(markup);
    \\  const before = document.queryCommandValue('formatblock');
    \\  for (const [c, v] of commands) document.execCommand(c, false, v);
    \\  return before + '|' + document.queryCommandValue('formatblock') + '|' + hostHTML();
    \\};
;

const ValueCase = struct {
    input: []const u8,
    commands: []const u8,
    /// "<value before>|<value after>|<innerHTML after>".
    expected: []const u8,
};

const value_cases = [_]ValueCase{
    // The empty blocks hold no visible position: the value is the third's
    // (the data's DOM after; Chrome keeps the empty blocks).
    .{ .input = "{<p><p> <p>foo</p>}", .commands = "[[\"formatblock\",\"<div>\"]]", .expected = "p|div|<div> foo</div>" },
    // A block holding other blocks is the value too.
    .{ .input = "<div><ol><li>[foo]</ol></div>", .commands = "[[\"formatblock\",\"<div>\"]]", .expected = "div|div|<div><ol><li>foo</li></ol></div>" },
    // A dl holding the range's dt and dd; after, the range spans two divs:
    // "" (Chrome and Safari make one div with a br, which reports "div").
    .{ .input = "<dl><dt>[foo<dd>bar]</dl>", .commands = "[[\"formatblock\",\"<div>\"]]", .expected = "dl||<div>foo</div><div>bar</div>" },
    // A dd line gets its dl (Firefox's DOM; all three report "dd").
    .{ .input = "<p>[foobar]</p>", .commands = "[[\"formatblock\",\"<dd>\"]]", .expected = "p|dd|<dl><dd>foobar</dd></dl>" },
    .{ .input = "<div>[foobar]</div>", .commands = "[[\"formatblock\",\"<dt>\"]]", .expected = "div|dt|<dl><dt>foobar</dt></dl>" },
    // xmp and listing are wrapped (listing: Chrome and Safari).
    .{ .input = "<xmp>[foo]</xmp>", .commands = "[[\"formatblock\",\"<p>\"]]", .expected = "|p|<p><xmp>foo</xmp></p>" },
    .{ .input = "<listing>[foobar]</listing>", .commands = "[[\"formatblock\",\"<div>\"]]", .expected = "|div|<div><listing>foobar</listing></div>" },
    // A line in a p inside a blockquote is wrapped.
    .{ .input = "<blockquote><p>[foo]<p>bar</blockquote><p>extra", .commands = "[[\"formatblock\",\"<blockquote>\"]]", .expected = "p|blockquote|<blockquote><blockquote>foo</blockquote><p>bar</p></blockquote><p>extra</p>" },
    // A container already of the name is rewrapped as one (the spec).
    .{ .input = "<div>[foobar]</div>", .commands = "[[\"formatblock\",\"<div>\"]]", .expected = "div|div|<div>foobar</div>" },
    .{ .input = "<p>[foo<p>bar]", .commands = "[[\"formatblock\",\"<p>\"]]", .expected = "||<p>foo</p><p>bar</p>" },
    // The new block takes the replaced container's attributes (all three).
    .{ .input = "<div style=color:blue>[foo]</div>", .commands = "[[\"stylewithcss\",\"false\"],[\"formatblock\",\"<p>\"]]", .expected = "div|p|<p style=\"color:blue\">foo</p>" },
    .{ .input = "<div style=color:blue>[foo]</div>", .commands = "[[\"stylewithcss\",\"true\"],[\"formatblock\",\"<p>\"]]", .expected = "div|p|<p style=\"color:blue\">foo</p>" },
    // Several blocks: "" (Chrome and Safari).
    .{ .input = "<p>[foo<p>bar]<p>baz", .commands = "[]", .expected = "||<p>foo</p><p>bar</p><p>baz</p>" },
};

fn valueCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(value_script);
    var failures: usize = 0;
    for (value_cases) |case| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "formatBlockValues({f}, {s})", .{ std.json.fmt(case.input, .{}), case.commands });
        defer std.testing.allocator.free(source);
        const actual = try page.evaluate(source);
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, case.expected, actual)) {
            std.debug.print("{s} on {s}: expected {s}, got {s}\n", .{ case.commands, case.input, case.expected, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "formatBlock: the browsers' value, dl wrapping, xmp and listing kept" {
    try helpers.onFreshThread(valueCases);
}
