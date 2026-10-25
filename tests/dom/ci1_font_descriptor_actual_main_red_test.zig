//! Font-family descriptor integration through the owning public parser.
//! These cases reproduced the legacy sharedText null unwrap after the
//! property migrated to typed families. Allocation-failure schedules verify
//! the descriptor retains its own serialized bytes after the Value releases.
const std = @import("std");
const fonts = @import("dom").style.engine.resource_loading.font_loading;

fn descriptor(allocator: std.mem.Allocator, text: []const u8, expected: []const u8) !void {
    const result = (try fonts.parseDescriptor(allocator, .family, text)) orelse return error.ExpectedFamilyDescriptor;
    defer allocator.free(result);
    try std.testing.expectEqualStrings(expected, result);
}

test "ci1 e2 family descriptor retains an unquoted name with allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, descriptor, .{ "Row119 Family", "Row119 Family" });
}

test "ci1 e2 family descriptor retains required quotes around a generic name" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, descriptor, .{ "'serif'", "\"serif\"" });
}

test "ci1 e2 family descriptor decodes an escaped identifier without text-value access" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, descriptor, .{ "F\\6f nt", "Font" });
}

test "ci1 e2 family descriptor retains a comma inside one quoted name" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, descriptor, .{ "'Ci1, Used'", "\"Ci1, Used\"" });
}

test "ci1 descriptor generic and family-list rejection stays independent" {
    for ([_][]const u8{ "serif", "inherit", "A, B", "" }) |text| {
        const result = try fonts.parseDescriptor(std.testing.allocator, .family, text);
        defer if (result) |value| std.testing.allocator.free(value);
        try std.testing.expect(result == null);
    }
}
