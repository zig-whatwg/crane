//! SVG2 §13.2: a URL paint server carries an optional color/none fallback.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectValue(property: []const u8, input: []const u8, expected: ?[]const u8) !void {
    const p = css.properties.lookup(property) orelse return error.MissingProperty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    const parsed = try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, p, input, &assignments);
    try testing.expectEqual(expected != null, parsed);
    if (expected) |text| {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        switch (p) {
            .longhand => |l| try css.properties.serializeAssigned(l, assignments.items[0].value, &out, testing.allocator),
            .shorthand => |s| {
                var assigned: [css.properties.max_assignments]css.properties.Assigned = undefined;
                for (s.longhands(), 0..) |l, i| {
                    for (assignments.items) |a| if (a.longhand == l) {
                        assigned[i] = a.value;
                    };
                }
                try testing.expect(try css.properties.serializeShorthand(s, assigned[0..s.longhands().len], .specified, &out, testing.allocator));
            },
        }
        try testing.expectEqualStrings(text, out.items);
    }
}

test "SVG paint accepts only one paint server and its optional fallback" {
    for ([_][]const u8{ "fill", "stroke" }) |p| {
        try expectValue(p, "none", "none");
        try expectValue(p, "context-fill", "context-fill");
        try expectValue(p, "context-stroke", "context-stroke");
        try expectValue(p, "ReD", "red");
        try expectValue(p, "url(#paint) currentColor", "url(\"#paint\") currentcolor");
        try expectValue(p, "url(a) none", "url(\"a\") none");
        try expectValue(p, "url(a) #00ff00", "url(\"a\") rgb(0, 255, 0)");
        for ([_][]const u8{ "auto", "none red", "red url(a)", "url(a) none red", "url(a) context-fill", "url(a), red", "linear-gradient(red,blue)" }) |bad| try expectValue(p, bad, null);
    }
}

test "marker expands and serializes three URL longhands" {
    try expectValue("marker", "url(a)", "url(\"a\")");
    try expectValue("marker", "none", "none");
    for ([_][]const u8{ "marker", "marker-start", "marker-mid", "marker-end" }) |p| {
        for ([_][]const u8{ "auto", "none url(a)", "url(a) red", "url(a), url(b)", "linear-gradient(red,blue)" }) |bad| try expectValue(p, bad, null);
    }
}

test "stroke-width accepts CSS numbers independently of SVG presentation parsing" {
    try expectValue("stroke-width", "10", "10");
    try expectValue("stroke-width", "0", "0px");
    try expectValue("stroke-width", "2em", "2em");
    try expectValue("stroke-width", "20%", "20%");
    try computed("stroke-width:10", "stroke-width", "10px");
    try computed("font-size:20px;stroke-width:2em", "stroke-width", "40px");
    try computed("", "stroke-width", "1px");
    for ([_][]const u8{ "-1", "-2em", "-3%", "5foo", "auto", "none", "1 2" }) |bad| try expectValue("stroke-width", bad, null);
}
fn computed(declarations: []const u8, property: []const u8, expected: []const u8) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, declarations);
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    const prop = css.properties.lookup(property) orelse return error.MissingProperty;
    try style.serializeResolved(prop.longhand, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "SVG paints compute named and system colors and resolve currentcolor" {
    try computed("color: lime; fill: currentcolor", "fill", "rgb(0, 255, 0)");
    try computed("fill: url(a) red", "fill", "url(\"a\") rgb(255, 0, 0)");
    try computed("color: blue; stroke: url(a) currentcolor", "stroke", "url(\"a\") rgb(0, 0, 255)");
    try computed("color-scheme: dark; fill: CanvasText", "fill", "rgb(255, 255, 255)");
    try computed("", "fill", "rgb(0, 0, 0)");
    try computed("", "stroke", "none");
}
