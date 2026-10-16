//! Captured cookie-change strings must be released if queue growth fails.
const std = @import("std");
const cookiestore = @import("cookiestore");

test "Cookie Store change record releases its clone on every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, recordChange, .{});
}

fn recordChange(allocator: std.mem.Allocator) !void {
    var observer = cookiestore.CookieChangeObserver.init(allocator);
    defer observer.deinit();
    const cookie: cookiestore.Cookie = .{
        .name = "captured-name",
        .value = "captured-value",
        .domain = "example.test",
        .path = "/cookie-store/",
        .creation_time = 0,
        .last_access_time = 0,
    };
    try observer.recordChange(.changed, cookie);
    try std.testing.expectEqual(@as(usize, 1), observer.pending_changes.items.len);
    try std.testing.expectEqualStrings(cookie.name, observer.pending_changes.items[0].cookie.name);
}
