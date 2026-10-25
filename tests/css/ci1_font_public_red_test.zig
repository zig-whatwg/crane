//! Public font-style controls and font-width defaults before typed enum recognition.
//! Fonts4 §§2.3–2.4; CSSOM §6.7.2. Existing public APIs only.
//! The original e1 tests and their assertions remain unchanged.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;

fn styleControls(allocator: Allocator) !void {
    const property = css.properties.lookup("font-style") orelse return error.ExpectedExistingFontStyle;
    for ([_][]const u8{ "normal", "italic", "oblique" }) |text| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (assignments.items) |item| item.value.release();
            assignments.deinit(allocator);
        }
        try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, text, &assignments));
        try testing.expectEqual(@as(usize, 1), assignments.items.len);
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try block.entries.ensureTotalCapacity(allocator, 1);
        assignments.items[0].value.retain();
        block.entries.appendAssumeCapacity(.{ .typed = .{
            .longhand = assignments.items[0].longhand,
            .value = assignments.items[0].value,
            .important = false,
        } });
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try block.getPropertyValue("font-style", &out);
        try testing.expectEqualStrings(text, out.items);
    }
    // Q26 keeps left/right invalid. All inputs already occur in the saved
    // scalar test, where its earlier positive failure can hide these checks.
    for ([_][]const u8{ "left", "right", "oblique 0", "oblique 91deg", "oblique -91deg", "italic 14deg", "oblique 10%" }) |text| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (assignments.items) |item| item.value.release();
            assignments.deinit(allocator);
        }
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator }, property, text, &assignments));
        try testing.expectEqual(@as(usize, 0), assignments.items.len);
    }
}

fn expectWidth(style: *const css.computed_style.ComputedStyle, allocator: Allocator, wanted: []const u8) !void {
    // This is observable property recognition, not a reference to a future
    // Zig enum field, module, or Value tag. A null lookup is an assertion RED.
    const property = css.properties.lookup("font-width");
    try testing.expect(property != null);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(property.?.longhand, &out, allocator);
    try testing.expectEqualStrings(wanted, out.items);
}

fn widthDefaults(allocator: Allocator) !void {
    const initial = try css.computed_style.ComputedStyle.initial(allocator);
    defer initial.destroy();
    try expectWidth(initial, allocator, "100%");
    for ([_][]const u8{ "", "font-width:inherit", "font-width:initial", "font-width:unset" }) |text| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        try expectWidth(style, allocator, "100%");
    }
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-width:condensed");
    defer block.deinit();
    const width = css.properties.lookup("font-width").?;
    try testing.expect(block.get(width.longhand) != null);
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    try expectWidth(child, allocator, "75%");
}

test "e1 existing font style and strict invalid controls remain independently reachable" {
    try testing.checkAllAllocationFailures(testing.allocator, styleControls, .{});
}

test "e1 font width defaults and inheritance are observable through public string lookup" {
    try testing.checkAllAllocationFailures(testing.allocator, widthDefaults, .{});
}
