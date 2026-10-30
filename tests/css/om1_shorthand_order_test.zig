//! CSSOM preferred shorthand order steps 1, 3-5; Q165/Q166.
//! Equal-size shorthands prefer unprefixed names before -webkit- names.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn check(input: []const u8, expected: []const u8, legacy_value: ?[]const u8) !void {
    const allocator = testing.allocator;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.serialize(&text);
    try testing.expectEqualStrings(expected, text.items);
    if (legacy_value) |value| {
        text.clearRetainingCapacity();
        try block.getPropertyValue("-webkit-line-clamp", &text);
        try testing.expectEqualStrings(value, text.items);
    }
}

test "preferred shorthand order chooses unprefixed line-clamp for legacy none" {
    try check("-webkit-line-clamp: none;", "line-clamp: none;", "none");
}

test "preferred shorthand order chooses unprefixed line-clamp for legacy positive integer" {
    try check("-webkit-line-clamp: 3;", "line-clamp: 3 -webkit-legacy;", "3");
}

test "preferred shorthand order preserves importance when choosing line-clamp" {
    try check("-webkit-line-clamp: 3 !important;", "line-clamp: 3 -webkit-legacy !important;", "3");
}

test "preferred shorthand order keeps an ordinary nonlegacy line-clamp" {
    try check("line-clamp: 3;", "line-clamp: 3;", null);
}

test "preferred shorthand order still groups four margin longhands" {
    try check("margin-top: 1px; margin-right: 1px; margin-bottom: 1px; margin-left: 1px;", "margin: 1px;", null);
}
