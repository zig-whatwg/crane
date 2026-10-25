//! Q207 mixed-state REDs for the Q206 interim shorthand storage seam.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn getValue(block: *const css.declarations.DeclarationBlock, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    return try allocator.dupe(u8, out.items);
}

fn priorTypedThenRaw(allocator: std.mem.Allocator, function: []const u8, earlier_important: bool) !void {
    const text = try std.fmt.allocPrint(allocator, "margin-left: 7px{s}; margin: {s};", .{ if (earlier_important) " !important" else "", function });
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();

    const margin = try getValue(&block, allocator, "margin");
    defer allocator.free(margin);
    const left = try getValue(&block, allocator, "margin-left");
    defer allocator.free(left);
    if (earlier_important) {
        try testing.expectEqualStrings("", margin);
        try testing.expectEqualStrings("7px", left);
        try testing.expect(block.getPropertyPriority("margin-left"));
    } else {
        try testing.expectEqualStrings(function, margin);
        try testing.expectEqualStrings("", left);
    }
}

fn priorTypedThenRawSetter(allocator: std.mem.Allocator, function: []const u8) !void {
    const text = try allocator.dupe(u8, "margin-left: 7px !important;");
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "margin", function, ""));
    const margin = try getValue(&block, allocator, "margin");
    defer allocator.free(margin);
    const left = try getValue(&block, allocator, "margin-left");
    defer allocator.free(left);
    try testing.expectEqualStrings(function, margin);
    try testing.expectEqualStrings("", left);
    try testing.expect(!block.getPropertyPriority("margin"));
}

fn rawThenTypedLonghand(allocator: std.mem.Allocator, function: []const u8, raw_important: bool, later_important: bool) !void {
    const text = try std.fmt.allocPrint(allocator, "margin: {s}{s}; margin-left: 7px{s};", .{
        function,
        if (raw_important) " !important" else "",
        if (later_important) " !important" else "",
    });
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();

    const margin = try getValue(&block, allocator, "margin");
    defer allocator.free(margin);
    const left = try getValue(&block, allocator, "margin-left");
    defer allocator.free(left);
    const right = try getValue(&block, allocator, "margin-right");
    defer allocator.free(right);
    const serialized = try cssText(allocator, &block);
    defer allocator.free(serialized);
    if (raw_important and !later_important) {
        // Parsed declaration importance remains normal: an earlier important
        // shorthand value wins over a later ordinary constituent declaration.
        try testing.expectEqualStrings(function, margin);
        try testing.expectEqualStrings("", left);
        try testing.expectEqualStrings("", right);
        try testing.expectEqual(@as(usize, 1), block.length());
        try testing.expectEqualStrings("margin", block.item(0).?);
        try testing.expect(block.getPropertyPriority("margin"));
        try testing.expect(std.mem.indexOf(u8, serialized, function) != null);
    } else {
        try testing.expectEqualStrings("", margin);
        try testing.expectEqualStrings("7px", left);
        try testing.expectEqualStrings("", right);
        try testing.expectEqual(later_important, block.getPropertyPriority("margin-left"));
        try testing.expectEqual(@as(usize, 1), block.length());
        try testing.expectEqualStrings("margin-left", block.item(0).?);
        try testing.expect(std.mem.indexOf(u8, serialized, "var(") == null);
        try testing.expect(std.mem.indexOf(u8, serialized, "env(") == null);
    }
}

fn cssText(allocator: std.mem.Allocator, block: *const css.declarations.DeclarationBlock) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.serialize(&out);
    return try allocator.dupe(u8, out.items);
}

fn rawThenTypedShorthand(allocator: std.mem.Allocator, function: []const u8, important: bool) !void {
    const text = try std.fmt.allocPrint(allocator, "margin: {s}{s}; margin: 1px{s};", .{
        function,
        if (important) " !important" else "",
        if (important) " !important" else "",
    });
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    const margin = try getValue(&block, allocator, "margin");
    defer allocator.free(margin);
    try testing.expectEqualStrings("1px", margin);
    try testing.expect(block.getPropertyPriority("margin") == important);
    const serialized = try cssText(allocator, &block);
    defer allocator.free(serialized);
    try testing.expect(std.mem.indexOf(u8, serialized, function) == null);
}

fn setLonghandAfterRawImportant(allocator: std.mem.Allocator, function: []const u8) !void {
    const text = try std.fmt.allocPrint(allocator, "margin: {s} !important;", .{function});
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "margin-left", "7px", ""));
    const margin = try getValue(&block, allocator, "margin");
    defer allocator.free(margin);
    const left = try getValue(&block, allocator, "margin-left");
    defer allocator.free(left);
    try testing.expectEqualStrings("", margin);
    try testing.expectEqualStrings("7px", left);
    try testing.expect(!block.getPropertyPriority("margin-left"));
    try testing.expectEqual(@as(usize, 1), block.length());
    try testing.expectEqualStrings("margin-left", block.item(0).?);
}

fn removeRawReturnsTrimmed(allocator: std.mem.Allocator, function: []const u8, important: bool) !void {
    const text = try std.fmt.allocPrint(allocator, "margin:   {s}   {s};", .{ function, if (important) "!important" else "" });
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    try testing.expect(try block.removeProperty("margin", &removed));
    try testing.expectEqualStrings(function, removed.items);
    try testing.expectEqual(@as(usize, 0), block.length());
}

fn setTypedShorthandAfterRaw(allocator: std.mem.Allocator, function: []const u8) !void {
    const text = try std.fmt.allocPrint(allocator, "margin: {s};", .{function});
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "margin", "1px", ""));
    const margin = try getValue(&block, allocator, "margin");
    defer allocator.free(margin);
    try testing.expectEqualStrings("1px", margin);
    const serialized = try cssText(allocator, &block);
    defer allocator.free(serialized);
    try testing.expect(std.mem.indexOf(u8, serialized, function) == null);
}

fn parsedTypedThenRaw(allocator: std.mem.Allocator) !void {
    inline for (.{ "var(--x)", "env(x)" }) |function| {
        try priorTypedThenRaw(allocator, function, false);
        try priorTypedThenRaw(allocator, function, true);
    }
}

fn rawLifecycle(allocator: std.mem.Allocator) !void {
    inline for (.{ "var(--x)", "env(x)" }) |function| {
        inline for (.{ false, true }) |raw_important| inline for (.{ false, true }) |later_important| {
            try rawThenTypedLonghand(allocator, function, raw_important, later_important);
        };
        try rawThenTypedShorthand(allocator, function, false);
        try rawThenTypedShorthand(allocator, function, true);
        try removeRawReturnsTrimmed(allocator, function, false);
        try removeRawReturnsTrimmed(allocator, function, true);
        try setTypedShorthandAfterRaw(allocator, function);
    }
}

fn setPropertyRemovesImportantTyped(allocator: std.mem.Allocator) !void {
    // Q209: setProperty uses setDeclaration's ordinary replacement behavior.
    inline for (.{ "var(--x)", "env(x)" }) |function| try priorTypedThenRawSetter(allocator, function);
}

fn setPropertyLonghandReplacesImportantRaw(allocator: std.mem.Allocator) !void {
    inline for (.{ "var(--x)", "env(x)" }) |function| try setLonghandAfterRawImportant(allocator, function);
}

fn parsedLonghandHonorsImportantRaw(allocator: std.mem.Allocator) !void {
    inline for (.{ "var(--x)", "env(x)" }) |function| try rawThenTypedLonghand(allocator, function, true, false);
}

test "parsed shorthand removes earlier typed constituents but keeps earlier important ones" {
    try testing.checkAllAllocationFailures(testing.allocator, parsedTypedThenRaw, .{});
}

test "setProperty raw shorthand replaces earlier important typed constituents" {
    try testing.checkAllAllocationFailures(testing.allocator, setPropertyRemovesImportantTyped, .{});
}

test "setProperty longhand replaces an important raw shorthand" {
    try testing.checkAllAllocationFailures(testing.allocator, setPropertyLonghandReplacesImportantRaw, .{});
}

test "parsed ordinary longhand honors an earlier important raw shorthand" {
    try testing.checkAllAllocationFailures(testing.allocator, parsedLonghandHonorsImportantRaw, .{});
}

test "raw shorthand replacement and removal keep trimmed CSSOM state" {
    try testing.checkAllAllocationFailures(testing.allocator, rawLifecycle, .{});
}
