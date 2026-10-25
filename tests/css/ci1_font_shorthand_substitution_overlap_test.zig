//! Q210 font/font-variant overlapping raw shorthand REDs; for the e2 commit.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn overlapLonghand(a_name: []const u8, b_name: []const u8) ![]const u8 {
    const a = (css.properties.lookup(a_name) orelse return error.MissingProperty).shorthand.longhands();
    const b = (css.properties.lookup(b_name) orelse return error.MissingProperty).shorthand.longhands();
    for (a) |x| for (b) |y| if (x == y) return x.name();
    return error.NoMetadataOverlap;
}

fn get(allocator: std.mem.Allocator, block: *const css.declarations.DeclarationBlock, name: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    return try allocator.dupe(u8, out.items);
}

fn parsed(allocator: std.mem.Allocator, old_name: []const u8, new_name: []const u8, old_value: []const u8, new_value: []const u8, old_important: bool, new_important: bool) !void {
    _ = try overlapLonghand(old_name, new_name);
    const input = try std.fmt.allocPrint(allocator, "{s}: {s}{s}; {s}: {s}{s};", .{ old_name, old_value, if (old_important) " !important" else "", new_name, new_value, if (new_important) " !important" else "" });
    defer allocator.free(input);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    const old_survives = old_important and !new_important;
    const old_got = try get(allocator, &block, old_name);
    defer allocator.free(old_got);
    const new_got = try get(allocator, &block, new_name);
    defer allocator.free(new_got);
    try testing.expectEqualStrings(if (old_survives) old_value else "", old_got);
    try testing.expectEqualStrings(if (old_survives) "" else new_value, new_got);
}

fn setter(allocator: std.mem.Allocator, old_name: []const u8, new_name: []const u8, old_value: []const u8, new_value: []const u8) !void {
    _ = try overlapLonghand(old_name, new_name);
    const input = try std.fmt.allocPrint(allocator, "{s}: {s} !important;", .{ old_name, old_value });
    defer allocator.free(input);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, new_name, new_value, ""));
    const old_got = try get(allocator, &block, old_name);
    defer allocator.free(old_got);
    const new_got = try get(allocator, &block, new_name);
    defer allocator.free(new_got);
    try testing.expectEqualStrings("", old_got);
    try testing.expectEqualStrings(new_value, new_got);
}

fn removeIntersection(allocator: std.mem.Allocator, shorthand: []const u8, function: []const u8) !void {
    const common = try overlapLonghand("font", "font-variant");
    const input = try std.fmt.allocPrint(allocator, "{s}:   {s}   !important;", .{ shorthand, function });
    defer allocator.free(input);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try testing.expect(try block.removeProperty(common, &out));
    try testing.expectEqualStrings("", out.items);
    try testing.expectEqual(@as(usize, 0), block.length());
}

fn removeRaw(allocator: std.mem.Allocator, shorthand: []const u8, function: []const u8) !void {
    const input = try std.fmt.allocPrint(allocator, "{s}:   {s}   !important;", .{ shorthand, function });
    defer allocator.free(input);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try testing.expect(try block.removeProperty(shorthand, &out));
    try testing.expectEqualStrings(function, out.items);
    try testing.expectEqual(@as(usize, 0), block.length());
}

test "font and font-variant overlap follows parsed priority in both directions" {
    try testing.checkAllAllocationFailures(testing.allocator, parsed, .{ "font", "font-variant", "var(--f)", "env(v)", false, false });
    try testing.checkAllAllocationFailures(testing.allocator, parsed, .{ "font-variant", "font", "env(v)", "var(--f)", false, false });
    try testing.checkAllAllocationFailures(testing.allocator, parsed, .{ "font", "font-variant", "var(--f)", "env(v)", true, false });
    try testing.checkAllAllocationFailures(testing.allocator, parsed, .{ "font-variant", "font", "env(v)", "var(--f)", true, false });
}

test "font and font-variant setProperty replacement ignores old priority in both directions" {
    try testing.checkAllAllocationFailures(testing.allocator, setter, .{ "font", "font-variant", "var(--f)", "env(v)" });
    try testing.checkAllAllocationFailures(testing.allocator, setter, .{ "font-variant", "font", "env(v)", "var(--f)" });
}

test "removing a font constituent invalidates the whole covering raw shorthand" {
    try testing.checkAllAllocationFailures(testing.allocator, removeIntersection, .{ "font", "var(--f)" });
    try testing.checkAllAllocationFailures(testing.allocator, removeIntersection, .{ "font-variant", "env(v)" });
}

test "removing a font or font-variant shorthand returns its trimmed raw text" {
    try testing.checkAllAllocationFailures(testing.allocator, removeRaw, .{ "font", "var(--f)" });
    try testing.checkAllAllocationFailures(testing.allocator, removeRaw, .{ "font-variant", "env(v)" });
}
