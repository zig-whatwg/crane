//! SVG2 §4.2 and Q11's three-browser probe: unitless lengths, not angles.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectAttribute(name: []const u8, text: []const u8, expected: ?[]const u8) !void {
    if (comptime !@hasDecl(css, "svg_presentation")) return error.PresentationAttributesNotImplemented;
    const presentation = css.svg_presentation;
    const property = presentation.lookup(presentation.svg_namespace, "rect", name) orelse return error.MissingProperty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try presentation.parse(.{ .allocator = testing.allocator }, presentation.svg_namespace, "rect", name, text, &assignments));
    if (expected) |computed| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        for (assignments.items) |assignment| {
            try block.entries.ensureUnusedCapacity(testing.allocator, 1);
            assignment.value.retain();
            block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = assignment.longhand, .value = assignment.value, .important = false } });
        }
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .presentational_hint } }});
        defer style.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try style.serializeResolved(property.longhand, &out, testing.allocator);
        try testing.expectEqualStrings(computed, out.items);
    } else try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

fn expectCssInvalid(name: []const u8, text: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.MissingProperty;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, property, text, &assignments));
    try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

test "SVG presentation unitless length mode does not become CSS quirks mode" {
    try expectAttribute("width", "5", "5px");
    try expectAttribute("font-size", "20", "20px");
    try expectAttribute("stroke-width", "5", "5px");
    try expectAttribute("stroke-width", "5foo", null);
    try expectCssInvalid("width", "5");
    try expectCssInvalid("font-size", "20");
}

test "SVG presentation nested filter lengths follow the three-browser probe" {
    // tmp/analysis/integrator-probes-1022e/results/svgfn-*.json: Firefox/Safari
    // accept blur's length; all three accept drop-shadow's lengths.
    try expectAttribute("filter", "blur(5)", "blur(5px)");
    try expectAttribute("filter", "drop-shadow(1 2)", "drop-shadow(rgb(0, 0, 0) 1px 2px 0px)");
    try expectAttribute("filter", "drop-shadow(1 -2 3)", "drop-shadow(rgb(0, 0, 0) 1px -2px 3px)");
    try expectAttribute("filter", "blur(-5)", null);
    try expectCssInvalid("filter", "blur(5)");
    try expectCssInvalid("filter", "drop-shadow(1 2)");
}

test "SVG presentation shape lengths and positions use the same unitless mode" {
    // All three engines accept the nested lengths in Q11's circle probe.
    try expectAttribute("clip-path", "circle(5 at 10 20)", "circle(5px at 10px 20px)");
    try expectAttribute("clip-path", "inset(1 2 3 4 round 5)", "inset(1px 2px 3px 4px round 5px)");
    try expectAttribute("clip-path", "circle(-5 at 10 20)", null);
    try expectCssInvalid("clip-path", "circle(5 at 10 20)");
}

test "SVG presentation unitless nonzero angle invalidates the whole filter" {
    // Chrome/Firefox reject these; Safari accepts. Q11 chooses the majority.
    try expectAttribute("filter", "hue-rotate(30)", null);
    try expectAttribute("filter", "blur(5) hue-rotate(30)", null);
    try expectAttribute("filter", "hue-rotate(30deg)", "hue-rotate(30deg)");
    try expectAttribute("filter", "blur(5) hue-rotate(30deg)", "blur(5px) hue-rotate(30deg)");
}
