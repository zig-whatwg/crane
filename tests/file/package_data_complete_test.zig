const std = @import("std");
const file = @import("file");

fn expectText(bytes: []const u8, mime: []const u8, label: ?[]const u8, expected: []const u8) !void {
    const result = try file.algorithms.packageData(std.testing.allocator, bytes, .Text, mime, label);
    defer std.testing.allocator.free(result.string);
    try std.testing.expectEqualStrings(expected, result.string);
}

test "File API package data maps every binary byte to its code unit" {
    const result = try file.algorithms.packageData(std.testing.allocator, &.{ 0, 0x7f, 0x80, 0xcf, 0x83, 0xff }, .BinaryString, "", null);
    defer std.testing.allocator.free(result.string);
    try std.testing.expectEqualStrings("\x00\x7f\xc2\x80\xc3\x8f\xc2\x83\xc3\xbf", result.string);
}

test "File API package data selects label then MIME then UTF-8 with BOM overriding" {
    try expectText(&.{0x80}, "text/plain;charset=windows-1252", null, "€");
    try expectText(&.{0x80}, "text/plain;charset=windows-1252", "invalid-label", "€");
    try expectText(&.{0x80}, "text/plain;charset=windows-1252", "utf-8", "�");
    try expectText(&.{0x80}, "invalid", null, "�");
    try expectText(&.{ 0xff, 0xfe, 0x41, 0 }, "", "windows-1252", "A");
    try expectText(&.{ 0xef, 0xbb, 0xbf, 0x41 }, "", "windows-1252", "A");
    try expectText(&.{ 0xe2, 0x82 }, "", null, "�");
}

test "File API package data uses the unanimous browser DataURL default" {
    const result = try file.algorithms.packageData(std.testing.allocator, "", .DataURL, "", null);
    defer std.testing.allocator.free(result.string);
    try std.testing.expectEqualStrings("data:application/octet-stream;base64,", result.string);
}

fn packageWithAllocationFailures(allocator: std.mem.Allocator) !void {
    const text = try file.algorithms.packageData(allocator, &.{0x80}, .Text, "text/plain;charset=windows-1252", null);
    defer allocator.free(text.string);
    try std.testing.expectEqualStrings("€", text.string);

    const binary = try file.algorithms.packageData(allocator, &.{0xff}, .BinaryString, "", null);
    defer allocator.free(binary.string);
    try std.testing.expectEqualStrings("ÿ", binary.string);

    const url = try file.algorithms.packageData(allocator, "A", .DataURL, "", null);
    defer allocator.free(url.string);
    try std.testing.expectEqualStrings("data:application/octet-stream;base64,QQ==", url.string);
}

test "File API packaging releases every partial allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, packageWithAllocationFailures, .{});
}
