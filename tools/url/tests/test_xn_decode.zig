const std = @import("std");
const punycode = @import("../src/idna/punycode.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test 1: ASCII- (from xn--ASCII-)
    std.debug.print("Test 1: xn--ASCII-\n", .{});
    const decoded1 = try punycode.decode(allocator, "ASCII-");
    defer allocator.free(decoded1);
    std.debug.print("  Decoded: '{s}'\n", .{decoded1});

    var is_ascii1 = true;
    for (decoded1) |byte| {
        if (byte >= 0x80) {
            is_ascii1 = false;
            break;
        }
    }
    std.debug.print("  Is pure ASCII: {}\n\n", .{is_ascii1});

    // Test 2: u-ccb (from xn--u-ccb)
    std.debug.print("Test 2: xn--u-ccb\n", .{});
    const decoded2 = try punycode.decode(allocator, "u-ccb");
    defer allocator.free(decoded2);
    std.debug.print("  Decoded bytes: ", .{});
    for (decoded2) |byte| {
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});

    var is_ascii2 = true;
    for (decoded2) |byte| {
        if (byte >= 0x80) {
            is_ascii2 = false;
            break;
        }
    }
    std.debug.print("  Is pure ASCII: {}\n", .{is_ascii2});
}
