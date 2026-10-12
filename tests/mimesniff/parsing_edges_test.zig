//! MIME Sniffing parser/serializer regression coverage from upstream WPT.
const std = @import("std");
const mimesniff = @import("mimesniff");

fn roundTrip(allocator: std.mem.Allocator, input: []const u8, expected: ?[]const u8) !void {
    const wide = try std.unicode.utf8ToUtf16LeAlloc(allocator, input);
    defer allocator.free(wide);
    var record = (try mimesniff.parseMimeTypeFromString(allocator, allocator, wide)) orelse {
        try std.testing.expect(expected == null);
        return;
    };
    defer record.deinit();
    const result = try mimesniff.serializeMimeType(allocator, record);
    defer allocator.free(result);
    const utf8 = try std.unicode.utf16LeToUtf8Alloc(allocator, result);
    defer allocator.free(utf8);
    try std.testing.expectEqualStrings(expected orelse return error.UnexpectedMimeType, utf8);
}

test "HTTP whitespace excludes form feed at every MIME boundary" {
    const a = std.testing.allocator;
    try roundTrip(a, "\x0cx/x", null);
    try roundTrip(a, "x/x\x0c", null);
    try roundTrip(a, "x/x\x0c;a=b", null);
    try roundTrip(a, "x/x;\x0ca=b;bonus=x", "x/x;bonus=x");
    try roundTrip(a, "x/x;a=b\x0c;bonus=x", "x/x;bonus=x");
    try roundTrip(a, "\r\nx/x\t ;\r\na=b\t ", "x/x;a=b");
}

test "MIME parameters keep the first valid duplicate and preserve order" {
    try roundTrip(std.testing.allocator, "X/X;CHARSET=gbk;a=b;charset=utf-8;A=c", "x/x;charset=gbk;a=b");
    try roundTrip(std.testing.allocator, "x/x;a=;a=\"\";a=b", "x/x;a=\"\"");
}

test "HTTP quoted string retains a final backslash" {
    try roundTrip(std.testing.allocator, "x/x;a=\"abc\\", "x/x;a=\"abc\\\\\"");
    try roundTrip(std.testing.allocator, "x/x;a=\"a\\\"b\\\\c\"junk;z=x", "x/x;a=\"a\\\"b\\\\c\";z=x");
}

fn allocationTrial(allocator: std.mem.Allocator) !void {
    try roundTrip(allocator, "custom/unknown;first=\"a b\";second=value;FIRST=ignored", "custom/unknown;first=\"a b\";second=value");
}

test "MIME parser and serializer release allocations on every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{});
}
