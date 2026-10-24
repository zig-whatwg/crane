//! CSS Masking1 §8.7; Q50's Safari-shipped mask-border reset set.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(input: []const u8, expected: ?[]const u8) !void {
    const property = css.properties.lookup("mask-border") orelse return error.MaskBorderNotImplemented;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, property, input, &assignments));
    if (expected) |text| {
        try testing.expectEqual(@as(usize, 5), assignments.items.len);
        var assigned: [5]css.properties.Assigned = undefined;
        for (assignments.items, &assigned) |a, *v| v.* = a.value;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try testing.expectEqual(text.len != 0, try css.properties.serializeShorthand(property.shorthand, &assigned, .specified, &out, testing.allocator));
        try testing.expectEqualStrings(text, out.items);
    } else try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

test "mask resets the five shipped mask border longhands and leaves unsupported mode out" {
    // Q50: tmp/analysis/integrator-probes-1023f/results/maskborder-*.json.
    try testing.expect(css.properties.lookup("mask-border-mode") == null);
    try testing.expectEqual(@as(usize, 13), css.properties.lookup("mask").?.shorthand.longhands().len);
    const property = css.properties.lookup("mask-border") orelse return error.MaskBorderNotImplemented;
    try testing.expectEqual(@as(usize, 5), property.shorthand.longhands().len);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "mask-border:url(old) 10 fill / 2 / 3 round;mask:none");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("mask-border", &out);
    try testing.expectEqualStrings("none", out.items);
}

test "mask border shorthand parses unordered groups and canonical quad components" {
    try check("none", "none");
    try check("url(a)", "url(\"a\")");
    try check("10", "10");
    try check("round", "round");
    try check("round url(a) 10 20 10 20 fill / 2px 3px / 4px", "url(\"a\") 10 20 fill / 2px 3px / 4px round");
    try check("10 fill url(a) stretch round", "url(\"a\") 10 fill stretch round");
    for ([_][]const u8{ "", "none, none", "10px", "10 / auto / 1%", "repeat-x", "alpha", "luminance", "10 fill fill", "repeat repeat repeat", "1 2 3 4 5", "url(a) url(b)", "10 / auto / 0 / 1" }) |invalid| try check(invalid, null);
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    _ = css.properties.lookup("mask-border") orelse return error.MaskBorderNotImplemented;
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://example.test/style.css", .referrer_policy = "origin" });
    var source_owned = true;
    defer if (source_owned) source.unref();
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .resource_source = source }, "font-size:20px;mask-border:url(a) 10% fill / 1em auto / 2em round");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    block.clear();
    source.unref();
    source_owned = false;
    const width = style.get(css.properties.lookup("mask-border-width").?.longhand);
    const outset = style.get(css.properties.lookup("mask-border-outset").?.longhand);
    const image = style.get(css.properties.lookup("mask-border-source").?.longhand);
    try testing.expectEqual(@as(usize, 1), image.resourceUrls().len);
    try testing.expectEqualStrings("origin", image.resourceUrls()[0].source.?.referrer_policy);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(css.properties.lookup("mask-border-width").?.longhand, width, &out, allocator);
    try testing.expectEqualStrings("20px auto", out.items);
    out.clearRetainingCapacity();
    try css.properties.serializeValue(css.properties.lookup("mask-border-outset").?.longhand, outset, &out, allocator);
    try testing.expectEqualStrings("40px", out.items);
}

test "mask border shorthand owns parsed and computed values across all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}

fn computedText(input: []const u8, expected: []const u8) !void {
    const property = css.properties.lookup("mask-border") orelse return error.MaskBorderNotImplemented;
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "mask-border", input, "");
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var assigned: [5]css.properties.Assigned = undefined;
    for (property.shorthand.longhands(), &assigned) |l, *v| v.* = .{ .value = style.get(l) };
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try testing.expect(try css.properties.serializeShorthand(property.shorthand, &assigned, .computed, &out, testing.allocator));
    try testing.expectEqualStrings(expected, out.items);
}

test "mask border canonicalization follows all eight Safari probe cases" {
    // Q52: tmp/analysis/integrator-probes-1023g/results/q89q52-*.json.
    try check("none", "none");
    try check("10 /", null);
    try check("10 / / 2", "10 / / 2");
    try check("0 / 2", "");
    try check("0 / / 2", "");
    try check("url(a) 0 / 2", "");
    try check("round url(a) 10 fill / auto / 2px", "url(\"a\") 10 fill / / 2px round");
    try check("fill 10", "10 fill");
    for ([_][]const u8{ "none", "10 / / 2", "0 / 2", "0 / / 2", "fill 10" }) |input| try computedText(input, "none");
    try computedText("url(a) 0 / 2", "url(\"a\") 0 / 2 / 0 stretch");
    try computedText("round url(a) 10 fill / auto / 2px", "url(\"a\") 10 fill / auto / 2px round");
}
