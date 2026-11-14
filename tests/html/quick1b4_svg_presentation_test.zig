//! SVG 2 §6.6: an SVG element's presentation attributes are presentational
//! hints - at the author origin, specificity 0, before every author rule
//! (CSS Cascade 5 §6.2), so an author rule or the style attribute wins over
//! them; a changed attribute changes the hint (src/dom/style/svg_hints.zig,
//! cached on the element's style state); an invalid value sets nothing; an
//! HTML element's attribute of the same name is no hint.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

const Case = struct {
    markup: []const u8,
    property: []const u8,
    expected: []const u8,
};

const cases = [_]Case{
    .{ .markup = "<svg><rect id=t fill=blue /></svg>", .property = "fill", .expected = "rgb(0, 0, 255)" },
    .{ .markup = "<svg><rect id=t stroke-width=4 /></svg>", .property = "stroke-width", .expected = "4px" },
    .{ .markup = "<svg><rect id=t opacity=0.5 /></svg>", .property = "opacity", .expected = "0.5" },
    // An author rule of any specificity wins over the hint.
    .{ .markup = "<style>rect { fill: red }</style><svg><rect id=t fill=blue /></svg>", .property = "fill", .expected = "rgb(255, 0, 0)" },
    // So does the style attribute.
    .{ .markup = "<svg><rect id=t fill=blue style=\"fill: lime\" /></svg>", .property = "fill", .expected = "rgb(0, 255, 0)" },
    // An invalid value sets nothing: the initial black.
    .{ .markup = "<svg><rect id=t fill=\"not a color\" /></svg>", .property = "fill", .expected = "rgb(0, 0, 0)" },
    // The hint is inherited like any other inherited property.
    .{ .markup = "<svg><g fill=blue><rect id=t /></g></svg>", .property = "fill", .expected = "rgb(0, 0, 255)" },
    // An HTML element's fill attribute is no hint.
    .{ .markup = "<div id=t fill=blue></div>", .property = "fill", .expected = "rgb(0, 0, 0)" },
};

fn hintsReachTheCascade() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<div id=box></div>';");
    var failures: usize = 0;
    for (cases) |case| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "box.innerHTML = {f}; getComputedStyle(box.querySelector('#t')).getPropertyValue({f})", .{ std.json.fmt(case.markup, .{}), std.json.fmt(case.property, .{}) });
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

test "SVG presentation attributes are presentational hints, below every author rule" {
    try helpers.onFreshThread(hintsReachTheCascade);
}

fn hintFollowsTheAttribute() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<svg><rect id=r fill=red /></svg>';");
    const first = try page.evaluate("getComputedStyle(r).fill");
    defer std.testing.allocator.free(first);
    try std.testing.expectEqualStrings("rgb(255, 0, 0)", first);
    // A changed attribute, after the first style, rebuilds the cached hint.
    try page.run("r.setAttribute('fill', 'blue');");
    const changed = try page.evaluate("getComputedStyle(r).fill");
    defer std.testing.allocator.free(changed);
    try std.testing.expectEqualStrings("rgb(0, 0, 255)", changed);
    // A second presentation attribute joins the same hint.
    try page.run("r.setAttribute('stroke', 'lime');");
    const stroke = try page.evaluate("getComputedStyle(r).stroke + ' ' + getComputedStyle(r).fill");
    defer std.testing.allocator.free(stroke);
    try std.testing.expectEqualStrings("rgb(0, 255, 0) rgb(0, 0, 255)", stroke);
    // A removed one drops its declaration.
    try page.run("r.removeAttribute('fill'); r.removeAttribute('stroke');");
    const removed = try page.evaluate("getComputedStyle(r).fill + ' ' + getComputedStyle(r).stroke");
    defer std.testing.allocator.free(removed);
    try std.testing.expectEqualStrings("rgb(0, 0, 0) none", removed);
}

test "an SVG presentation hint follows its attribute after the first style" {
    try helpers.onFreshThread(hintFollowsTheAttribute);
}
