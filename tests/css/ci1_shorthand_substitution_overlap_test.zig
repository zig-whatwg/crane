//! Q210 generic overlapping raw shorthand REDs for the Q206 interim seam.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn value(allocator: std.mem.Allocator, block: *const css.declarations.DeclarationBlock, name: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    return try allocator.dupe(u8, out.items);
}

fn metadataOverlap(a_name: []const u8, b_name: []const u8) !void {
    const a = (css.properties.lookup(a_name) orelse return error.MissingProperty).shorthand.longhands();
    const b = (css.properties.lookup(b_name) orelse return error.MissingProperty).shorthand.longhands();
    for (a) |x| for (b) |y| if (x == y) return;
    return error.NoMetadataOverlap;
}

fn parsedOverlap(allocator: std.mem.Allocator, old_name: []const u8, new_name: []const u8, old_value: []const u8, new_value: []const u8, old_important: bool, new_important: bool) !void {
    try metadataOverlap(old_name, new_name);
    const input = try std.fmt.allocPrint(allocator, "{s}: {s}{s}; {s}: {s}{s};", .{
        old_name,
        old_value,
        if (old_important) " !important" else "",
        new_name,
        new_value,
        if (new_important) " !important" else "",
    });
    defer allocator.free(input);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    const old_survives = old_important and !new_important;
    const old_got = try value(allocator, &block, old_name);
    defer allocator.free(old_got);
    const new_got = try value(allocator, &block, new_name);
    defer allocator.free(new_got);
    try testing.expectEqualStrings(if (old_survives) old_value else "", old_got);
    try testing.expectEqualStrings(if (old_survives) "" else new_value, new_got);
    // Q211 PART 2: an important old entry drops a fully covered parsed
    // newcomer; partial coverage still retains that raw entry.
    const old_longhands = (css.properties.lookup(old_name) orelse return error.MissingProperty).shorthand.longhands();
    const new_longhands = (css.properties.lookup(new_name) orelse return error.MissingProperty).shorthand.longhands();
    const fully_covered = covered: {
        for (new_longhands) |longhand| {
            for (old_longhands) |old_longhand| {
                if (longhand == old_longhand) break;
            } else break :covered false;
        }
        break :covered true;
    };
    try testing.expectEqual(@as(usize, if (old_survives and !fully_covered) 2 else 1), block.length());
}

fn setterOverlap(allocator: std.mem.Allocator, old_name: []const u8, new_name: []const u8, old_value: []const u8, new_value: []const u8, old_important: bool) !void {
    try metadataOverlap(old_name, new_name);
    const input = try std.fmt.allocPrint(allocator, "{s}: {s}{s};", .{ old_name, old_value, if (old_important) " !important" else "" });
    defer allocator.free(input);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, new_name, new_value, ""));
    const old_got = try value(allocator, &block, old_name);
    defer allocator.free(old_got);
    const new_got = try value(allocator, &block, new_name);
    defer allocator.free(new_got);
    try testing.expectEqualStrings("", old_got);
    try testing.expectEqualStrings(new_value, new_got);
    try testing.expectEqual(@as(usize, 1), block.length());
    try testing.expectEqualStrings(new_name, block.item(0).?);
}

fn removeConstituent(allocator: std.mem.Allocator, shorthand: []const u8, function: []const u8) !void {
    const text = try std.fmt.allocPrint(allocator, "{s}:   {s}   !important;", .{ shorthand, function });
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    try testing.expect(try block.removeProperty("border-top-color", &removed));
    try testing.expectEqualStrings("", removed.items);
    try testing.expectEqual(@as(usize, 0), block.length());
    const got = try value(allocator, &block, shorthand);
    defer allocator.free(got);
    try testing.expectEqualStrings("", got);
}

fn removeShorthand(allocator: std.mem.Allocator, shorthand: []const u8, function: []const u8) !void {
    const text = try std.fmt.allocPrint(allocator, "{s}:   {s}   !important;", .{ shorthand, function });
    defer allocator.free(text);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    try testing.expect(try block.removeProperty(shorthand, &removed));
    try testing.expectEqualStrings(function, removed.items);
    try testing.expectEqual(@as(usize, 0), block.length());
}

test "parsed border and border-color overlap obeys importance in both directions" {
    try testing.checkAllAllocationFailures(testing.allocator, parsedOverlap, .{ "border", "border-color", "var(--x)", "env(x)", false, false });
    try testing.checkAllAllocationFailures(testing.allocator, parsedOverlap, .{ "border-color", "border", "env(x)", "var(--x)", false, false });
    try testing.checkAllAllocationFailures(testing.allocator, parsedOverlap, .{ "border", "border-color", "var(--x)", "env(x)", true, false });
    try testing.checkAllAllocationFailures(testing.allocator, parsedOverlap, .{ "border-color", "border", "env(x)", "var(--x)", true, false });
}

test "setProperty border and border-color overlap ignores prior importance in both directions" {
    try testing.checkAllAllocationFailures(testing.allocator, setterOverlap, .{ "border", "border-color", "var(--x)", "env(x)", true });
    try testing.checkAllAllocationFailures(testing.allocator, setterOverlap, .{ "border-color", "border", "env(x)", "var(--x)", true });
}

test "removing a border constituent removes its whole covering raw shorthand" {
    try testing.checkAllAllocationFailures(testing.allocator, removeConstituent, .{ "border", "var(--x)" });
    try testing.checkAllAllocationFailures(testing.allocator, removeConstituent, .{ "border-color", "env(x)" });
}

test "removing an overlapping raw shorthand returns its trimmed authored value" {
    try testing.checkAllAllocationFailures(testing.allocator, removeShorthand, .{ "border", "var(--x)" });
    try testing.checkAllAllocationFailures(testing.allocator, removeShorthand, .{ "border-color", "env(x)" });
}
