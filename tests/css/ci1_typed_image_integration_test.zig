//! Shared typed image choices at content, cursor and background boundaries.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Value = css.style_values.Value;

fn expectResolved(style: *const css.computed_style.ComputedStyle, longhand: css.properties.Longhand, expected: []const u8, allocator: std.mem.Allocator) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try style.serializeResolved(longhand, &text, allocator);
    try testing.expectEqualStrings(expected, text.items);
}

fn computedImages(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color-scheme:dark;" ++
        "background-image:url(first),light-dark(url(light),url(dark)),none;" ++
        "content:light-dark(image-set(url(light)),image-set(url(dark) 192dpi)) attr(label,'tail');" ++
        "cursor:light-dark(image-set(url(light) 1x),url(dark)) 1.5 -2.9,pointer");
    var block_owned = true;
    defer if (block_owned) block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    block.deinit();
    block_owned = false;
    try expectResolved(parent, .background_image, "url(\"first\"), url(\"dark\"), none", allocator);
    try expectResolved(parent, .content, "image-set(url(\"dark\") 2dppx) \"tail\"", allocator);
    try expectResolved(parent, .cursor, "url(\"dark\") 1.5 -2.9, pointer", allocator);
    var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color-scheme:light;background-image:inherit;content:inherit;cursor:inherit");
    defer inherited.deinit();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherited, .source = .{ .origin = .author } }});
    defer child.destroy();
    try expectResolved(child, .background_image, "url(\"first\"), url(\"dark\"), none", allocator);
    try expectResolved(child, .content, "image-set(url(\"dark\") 2dppx) \"tail\"", allocator);
    try expectResolved(child, .cursor, "url(\"dark\") 1.5 -2.9, pointer", allocator);
}

test "image choices compute every component before inheritance and keep their ownership" {
    try testing.checkAllAllocationFailures(testing.allocator, computedImages, .{});
}

fn shorthandImages(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color-scheme:dark;background:image-set(url(one),url(two) 2x),light-dark(url(light),url(dark)) red");
    var block_owned = true;
    defer if (block_owned) block.deinit();
    var specified: std.ArrayList(u8) = .empty;
    defer specified.deinit(allocator);
    try block.getPropertyValue("background", &specified);
    try testing.expectEqualStrings("image-set(url(\"one\") 1x, url(\"two\") 2x), light-dark(url(\"light\"), url(\"dark\")) red", specified.items);
    var control = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "background-image:image-set(url(one),url(two) 2x),light-dark(url(light),url(dark))");
    defer control.deinit();
    const shorthand_image = block.get(.background_image).?.value.value;
    const longhand_image = control.get(.background_image).?.value.value;
    try testing.expect(shorthand_image.eql(longhand_image));
    try testing.expect(shorthand_image.resourcesEql(longhand_image));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    block.deinit();
    block_owned = false;
    try expectResolved(style, .background_image, "image-set(url(\"one\") 1dppx, url(\"two\") 2dppx), url(\"dark\")", allocator);
    const image = style.get(.background_image);
    try testing.expectEqual(@as(usize, 3), image.resourceUrls().len);
    try testing.expectEqualStrings("dark", image.resourceUrls()[2].url);
    try expectResolved(style, .background_color, "rgb(255, 0, 0)", allocator);
    var computed_shorthand: std.ArrayList(u8) = .empty;
    defer computed_shorthand.deinit(allocator);
    const assigned = [_]css.properties.Assigned{
        .{ .value = style.get(.background_image) },
        .{ .value = style.get(.background_color) },
    };
    try testing.expect(try css.properties.serializeShorthand(.background, &assigned, .computed, &computed_shorthand, allocator));
    try testing.expectEqualStrings("rgb(255, 0, 0) image-set(url(\"one\") 1dppx, url(\"two\") 2dppx), url(\"dark\")", computed_shorthand.items);
}

test "background shorthand keeps typed image candidates instead of flattening them" {
    try testing.checkAllAllocationFailures(testing.allocator, shorthandImages, .{});
}

test "typed image functions close at EOF through content and image properties" {
    const cases = [_]struct { []const u8, []const u8 }{
        .{ "image-set(url(a)", "image-set(url(\"a\") 1x)" },
        .{ "image-set(url(a) type('image/png'", "image-set(url(\"a\") 1x type(\"image/png\"))" },
        .{ "light-dark(url(a),none", "light-dark(url(\"a\"), none)" },
        .{ "-webkit-cross-fade(url(a),url(b),50%", "-webkit-cross-fade(url(\"a\"), url(\"b\"), 0.5)" },
    };
    for ([_]css.properties.Longhand{ .content, .background_image, .list_style_image }) |longhand| for (cases) |case| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (assignments.items) |item| item.value.release();
            assignments.deinit(testing.allocator);
        }
        try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = longhand }, case[0], &assignments));
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(testing.allocator);
        try css.properties.serializeValue(longhand, assignments.items[0].value.value, &text, testing.allocator);
        try testing.expectEqualStrings(case[1], text.items);
    };
}

test "cursor and content declaration reuse respects typed image identity" {
    for ([_][]const u8{ "cursor", "content" }) |name| {
        const omitted = if (std.mem.eql(u8, name, "cursor")) "image-set(url(a)),pointer" else "image-set(url(a))";
        const explicit = if (std.mem.eql(u8, name, "cursor")) "image-set(url(a) 1x),pointer" else "image-set(url(a) 1x)";
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        const options = css.properties.ParseOptions{ .allocator = testing.allocator };
        try testing.expect(try block.setProperty(options, name, omitted, ""));
        const before: Value = block.get(css.properties.lookup(name).?.longhand).?.value.value;
        before.retain();
        defer before.release();
        try testing.expect(try block.setProperty(options, name, explicit, ""));
        const after: Value = block.get(css.properties.lookup(name).?.longhand).?.value.value;
        try testing.expect(!before.eql(after));
        try testing.expect(before.resourcesEql(after));
        try testing.expect(!try block.setProperty(options, name, explicit, ""));
    }
}
