const std = @import("std");
const URL = @import("../src/url.zig").URL;
const helpers = @import("url").test_helpers;

test "debug setUsername corruption" {
    const allocator = std.testing.allocator;

    std.debug.print("\n=== Test: setUsername corruption ===\n", .{});

    var url = try helpers.initURL(allocator, "http://example.com/", null);
    defer url.deinit();

    std.debug.print("1. Initial URL created\n", .{});
    std.debug.print("   buffer ptr = {*}\n", .{url.internal.buffer.ptr});
    std.debug.print("   buffer.len = {}\n", .{url.internal.buffer.len});
    std.debug.print("   buffer = '{s}'\n", .{url.internal.buffer});
    const href1 = try url.get_href();
    defer allocator.free(href1);
    std.debug.print("   href = {s}\n", .{href1});

    std.debug.print("\n2. About to call setUsername(\"user\")\n", .{});
    const old_buffer_ptr = url.internal.buffer.ptr;

    try url.set_username("user");

    std.debug.print("3. After setUsername\n", .{});
    std.debug.print("   buffer ptr = {*} (changed: {})\n", .{ url.internal.buffer.ptr, url.internal.buffer.ptr != old_buffer_ptr });
    std.debug.print("   buffer.len = {}\n", .{url.internal.buffer.len});
    if (url.internal.buffer.len > 0) {
        std.debug.print("   buffer = '{s}'\n", .{url.internal.buffer});
    } else {
        std.debug.print("   buffer = <empty>\n", .{});
    }

    std.debug.print("4. Checking internal fields:\n", .{});
    std.debug.print("   scheme = '{s}'\n", .{url.internal.scheme()});
    std.debug.print("   username = '{s}'\n", .{url.internal.get_username()});
    std.debug.print("   host = {?}\n", .{url.internal.host});
    std.debug.print("   path = {any}\n", .{url.internal.path});

    const href2 = try url.get_href();
    defer allocator.free(href2);
    std.debug.print("\n5. Final href = {s}\n", .{href2});
}
