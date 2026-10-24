//! Backgrounds3 §§2–3 / Backgrounds4 §2.6: independent components and layers.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectValue(name: []const u8, input: []const u8, expected: ?[]const u8) !void {
    const property = css.properties.lookup(name) orelse return error.BackgroundComponentNotImplemented;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, property, input, &assignments));
    if (expected) |text| {
        const declaration = try std.fmt.allocPrint(testing.allocator, "{s}:{s}", .{ name, input });
        defer testing.allocator.free(declaration);
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, declaration);
        defer block.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.getPropertyValue(name, &out);
        try testing.expectEqualStrings(text, out.items);
    }
}

fn expectBlock(block: *const css.declarations.DeclarationBlock, name: []const u8, expected: []const u8, allocator: std.mem.Allocator) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

test "background axes accept their own edges and reject opposite edges or center offsets" {
    try expectValue("background-position-x", "center, left -20%, right 10px, x-start, x-end", "center, left -20%, right 10px, x-start, x-end");
    try expectValue("background-position-y", "center, top -20%, bottom 10px, y-start, y-end", "center, top -20%, bottom 10px, y-start, y-end");
    for ([_][]const u8{ "top", "bottom", "y-start", "y-end", "center 1px", "left right", "left 1px 2px", "10", "left," }) |bad| try expectValue("background-position-x", bad, null);
    for ([_][]const u8{ "left", "right", "x-start", "x-end", "center 1px", "top bottom", "top 1px 2px", "10", "top," }) |bad| try expectValue("background-position-y", bad, null);
}

test "background position mutation preserves the other axis and refuses unmatched lists" {
    _ = css.properties.lookup("background-position-x") orelse return error.BackgroundComponentNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "background-position:top left, right 10px bottom 20px;background-position-x:center,right 3px");
    defer block.deinit();
    try expectBlock(&block, "background-position-x", "center, right 3px", testing.allocator);
    try expectBlock(&block, "background-position-y", "top, bottom 20px", testing.allocator);
    try expectBlock(&block, "background-position", "center top, right 3px bottom 20px", testing.allocator);
    var unequal = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "background-position-x:center,right;background-position-y:bottom");
    defer unequal.deinit();
    try expectBlock(&unequal, "background-position", "", testing.allocator);
}

test "background shorthand preserves components resets all longhands and allows color only last" {
    try expectValue("background", "url(a) top left no-repeat, url(b) center / 100% 100% fixed content-box padding-box white", "url(\"a\") left top no-repeat, url(\"b\") center center / 100% 100% fixed content-box padding-box white");
    try expectValue("background", "padding-box border-box", "none");
    try expectValue("background", "url(a) 0% 0% / 10rem", "url(\"a\") 0% 0% / 10rem auto");
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "background-size:cover;background-repeat:no-repeat;background-position-x:right;background-position-y:bottom;background-origin:content-box;background-clip:content-box;background-attachment:fixed;background-color:red;background-image:url(old);background:none");
    defer block.deinit();
    const names = .{ "background-image", "background-position-x", "background-position-y", "background-size", "background-repeat", "background-attachment", "background-origin", "background-clip", "background-color" };
    // Q86 user decision: an omitted declared color is transparent.
    // Row 118 owns that initial; consume its follow-up only through main.
    const initial = .{ "none", "0%", "0%", "auto", "repeat", "scroll", "padding-box", "border-box", "transparent" };
    inline for (names, initial) |name, value| try expectBlock(&block, name, value, testing.allocator);
    for ([_][]const u8{ "red, url(a)", "none red, none", "none,", "none,,none", "center /", "center / cover / contain", "fixed local", "padding-box content-box border-box", "repeat-x repeat-y", "top top", "red blue" }) |bad| try expectValue("background", bad, null);
}

test "background clip accepts border-area plus text and uses border-box origin for clip-only forms" {
    // Backgrounds4: Chrome ships border-area || text; Safari ships border-area.
    try expectValue("background-clip", "text border-area, content-box", "border-area text, content-box");
    try expectValue("background", "border-area border-box", "border-area");
    try expectValue("background", "border-area padding-box", "padding-box border-area");
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "background:text border-area");
    defer block.deinit();
    try expectBlock(&block, "background-clip", "border-area text", testing.allocator);
    try expectBlock(&block, "background-origin", "border-box", testing.allocator);
    for ([_][]const u8{ "border-box text", "border-area border-area", "text text", "margin-box" }) |bad| try expectValue("background-clip", bad, null);
}

fn layersAndOwnership(allocator: std.mem.Allocator) !void {
    const x = css.properties.lookup("background-position-x") orelse return error.BackgroundComponentNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:20px;direction:rtl;background:url(a) right 1em bottom 2em / 3em auto no-repeat,none;background-position-x:x-start,10px,right 5px;background-size:1em");
    var block_owned = true;
    defer if (block_owned) block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    block.deinit();
    block_owned = false;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(x.longhand, &out, allocator);
    try testing.expectEqualStrings("100%, 10px, calc(100% - 5px)", out.items);
    out.clearRetainingCapacity();
    try style.serializeResolved(css.properties.lookup("background-size").?.longhand, &out, allocator);
    // Q119 (q119-C6/P1/P5): resolved size repeats to the two images.
    try testing.expectEqualStrings("20px auto, 20px auto", out.items);
    const image = style.get(css.properties.lookup("background-image").?.longhand);
    try testing.expectEqual(@as(usize, 1), image.resourceUrls().len);
    try testing.expectEqualStrings("a", image.resourceUrls()[0].url);
}

test "background computed axes and lists survive declaration destruction and every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, layersAndOwnership, .{});
}

// Q47: integrator-probes-1023d/results/bglogical-*.json. Safari ships
// x/y-relative edges; all three reject block/inline expansion pending #9690.
test "background logical axis edges resolve at computation in both writing modes" {
    for ([_][]const u8{ "horizontal-tb", "vertical-rl" }, [_][]const u8{ "0% 100%", "100% 100%" }) |mode, expected| {
        const declaration = try std.fmt.allocPrint(testing.allocator, "writing-mode:{s};background-position:x-start y-end", .{mode});
        defer testing.allocator.free(declaration);
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, declaration);
        defer block.deinit();
        try expectBlock(&block, "background-position-x", "x-start", testing.allocator);
        try expectBlock(&block, "background-position-y", "y-end", testing.allocator);
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        const x = (css.properties.lookup("background-position-x") orelse return error.BackgroundComponentNotImplemented).longhand;
        const y = css.properties.lookup("background-position-y").?.longhand;
        try style.serializeResolved(x, &out, testing.allocator);
        try out.append(testing.allocator, ' ');
        try style.serializeResolved(y, &out, testing.allocator);
        try testing.expectEqualStrings(expected, out.items);
    }
    for ([_][]const u8{ "block-start inline-end", "start end", "inline-end 10px block-start 20px" }) |bad| try expectValue("background-position", bad, null);
    try testing.expect(css.properties.lookup("background-position-block") == null);
    try testing.expect(css.properties.lookup("background-position-inline") == null);
}

test "background axis values forward unavailable font metrics" {
    const Value = css.style_values.Value;
    if (comptime !@hasField(Value, "image_axis")) return error.BackgroundComponentNotImplemented;
    const scalar = (try css.math_values.parse(testing.allocator, "calc(1cap)", .{ .kind = .length_percentage })) orelse return error.MissingMath;
    const value = Value{ .calculation = scalar.expression };
    defer value.release();
    const Axis = std.meta.Child(@FieldType(Value, "image_axis"));
    const axis: Value = .{ .image_axis = try Axis.create(testing.allocator, .{ .edge = .right, .offset = value }) };
    defer axis.release();
    try testing.expect(axis.needsUnavailableMetrics(false));
    try testing.expect(!axis.needsUnavailableMetrics(true));
}
