//! Font Loading3 §2.1 / Fonts4 §4.8.2: acceptance requires decoded font data.
const std = @import("std");
const platform = @import("platform");
const fonts = @import("dom").style.engine.resource_loading.font_loading;
const testing = std.testing;

fn expectValidation(expected: fonts.FontValidation, allocator: std.mem.Allocator, bytes: []const u8, fragment: []const u8) !void {
    const actual = try fonts.validateFontData(allocator, bytes, fragment);
    try testing.expectEqual(if (platform.capabilities.font_decoding == .unsupported) .cannot_validate else expected, actual);
}

test "font validation accepts real Ahem and releases its decoded names" {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/fonts/Ahem.ttf", testing.allocator, .limited(16 << 20));
    defer testing.allocator.free(bytes);
    try expectValidation(.valid, testing.allocator, bytes, "");
    try expectValidation(.valid, testing.allocator, bytes, "Ahem");
    try expectValidation(.invalid, testing.allocator, bytes[0 .. bytes.len / 2], "");
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn exercise(allocator: std.mem.Allocator, data: []const u8) !void {
            try expectValidation(.valid, allocator, data, "Ahem");
        }
    }.exercise, .{bytes});
}

test "font validation rejects garbage and empty buffers" {
    try expectValidation(.invalid, testing.allocator, "not a font", "");
    try expectValidation(.invalid, testing.allocator, &.{}, "");
}

test "font validation passes a collection's PostScript fragment to its decoder" {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(testing.io, "tests/wpt/css/css-fonts/variations/resources/ahem.ttc", testing.allocator, .limited(16 << 20));
    defer testing.allocator.free(bytes);
    // Selection itself is independently checked in platform/font_decoding_test.
    try expectValidation(.valid, testing.allocator, bytes, "AhemNBSP");
    // Q21 / protocol's decodeFont contract: successful face-0 fallback also
    // validates, including a serialized fragment that is not decoded here.
    try expectValidation(.valid, testing.allocator, bytes, "MissingPostScriptName");
    try expectValidation(.valid, testing.allocator, bytes, "Ahem%4EBSP");
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn exercise(allocator: std.mem.Allocator, data: []const u8) !void {
            try expectValidation(.valid, allocator, data, "AhemNBSP");
        }
    }.exercise, .{bytes});
}

test "font validation rejects a resource above the 128 MiB input limit before parsing" {
    const bytes = try testing.allocator.alloc(u8, (128 << 20) + 1);
    defer testing.allocator.free(bytes);
    // The size check must precede any read of these uninitialized bytes.
    try expectValidation(.invalid, testing.allocator, bytes, "");
}
