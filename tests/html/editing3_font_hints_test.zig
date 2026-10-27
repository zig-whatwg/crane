//! Lane editing3, unit 2: the font element's presentational hints (HTML
//! 15.3.4, src/dom/style/font_hints.zig): color through the rules for
//! parsing a legacy color value, face as 'font-family', size through the
//! rules for parsing a legacy font size - read back with
//! getComputedStyle(), as the Editing spec's effective command values read
//! them.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

const Case = struct {
    markup: []const u8,
    property: []const u8,
    expected: []const u8,
};

const cases = [_]Case{
    .{ .markup = "<font color=red>x</font>", .property = "color", .expected = "rgb(255, 0, 0)" },
    .{ .markup = "<font color=#00f>x</font>", .property = "color", .expected = "rgb(0, 0, 255)" },
    .{ .markup = "<font color=00ff00>x</font>", .property = "color", .expected = "rgb(0, 255, 0)" },
    .{ .markup = "<font color=potato>x</font>", .property = "color", .expected = "rgb(0, 10, 0)" },
    // "transparent" and the empty string are failure: no hint, the
    // inherited black.
    .{ .markup = "<font color=transparent>x</font>", .property = "color", .expected = "rgb(0, 0, 0)" },
    .{ .markup = "<font color=\"\">x</font>", .property = "color", .expected = "rgb(0, 0, 0)" },
    .{ .markup = "<font face=monospace>x</font>", .property = "font-family", .expected = "monospace" },
    .{ .markup = "<font size=1>x</font>", .property = "font-size", .expected = "10px" },
    .{ .markup = "<font size=3>x</font>", .property = "font-size", .expected = "16px" },
    .{ .markup = "<font size=+2>x</font>", .property = "font-size", .expected = "24px" },
    .{ .markup = "<font size=-1>x</font>", .property = "font-size", .expected = "13px" },
    .{ .markup = "<font size=7>x</font>", .property = "font-size", .expected = "48px" },
    .{ .markup = "<font size=12>x</font>", .property = "font-size", .expected = "48px" },
    .{ .markup = "<font size=foo>x</font>", .property = "font-size", .expected = "16px" },
    // An author declaration beats the hint (presentational hints come
    // before the author origin).
    .{ .markup = "<font color=red style=\"color: blue\">x</font>", .property = "color", .expected = "rgb(0, 0, 255)" },
    // The hint is inherited like any other color.
    .{ .markup = "<font color=red><span>x</span></font>", .property = "color", .expected = "rgb(255, 0, 0)" },
};

fn hintsReachTheCascade() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<div id=box></div>';");
    var failures: usize = 0;
    for (cases) |case| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "box.innerHTML = {f}; getComputedStyle(box.querySelector('span') || box.firstChild).getPropertyValue({f})", .{ std.json.fmt(case.markup, .{}), std.json.fmt(case.property, .{}) });
        defer std.testing.allocator.free(source);
        const actual = try page.evaluate(source);
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) {
            std.debug.print("{s} {s}: expected {s}, got {s}\n", .{ case.markup, case.property, case.expected, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "font color, face and size are presentational hints" {
    try helpers.onFreshThread(hintsReachTheCascade);
}

fn hintFollowsTheAttribute() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<font id=f color=red>x</font>';");
    const first = try page.evaluate("getComputedStyle(f).color");
    defer std.testing.allocator.free(first);
    try std.testing.expectEqualStrings("rgb(255, 0, 0)", first);
    // A changed attribute rebuilds the cached hint; a removed one drops it.
    try page.run("f.setAttribute('color', 'blue');");
    const changed = try page.evaluate("getComputedStyle(f).color");
    defer std.testing.allocator.free(changed);
    try std.testing.expectEqualStrings("rgb(0, 0, 255)", changed);
    try page.run("f.removeAttribute('color');");
    const removed = try page.evaluate("getComputedStyle(f).color");
    defer std.testing.allocator.free(removed);
    try std.testing.expectEqualStrings("rgb(0, 0, 0)", removed);
    // Only an HTML font element: an SVG-namespace "font" gets no hint.
    try page.run("const other = document.createElementNS('http://www.w3.org/2000/svg', 'font'); other.setAttribute('color', 'red'); document.body.appendChild(other);");
    const svg = try page.evaluate("getComputedStyle(document.body.lastChild).color");
    defer std.testing.allocator.free(svg);
    try std.testing.expectEqualStrings("rgb(0, 0, 0)", svg);
}

test "the font hint follows its attributes" {
    try helpers.onFreshThread(hintFollowsTheAttribute);
}
