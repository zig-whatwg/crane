//! Each actual cookie store mutation produces one native change record.
const std = @import("std");
const cookies = @import("cookiestore");

const Records = struct {
    count: usize = 0,
    secure_count: usize = 0,
    deleted_count: usize = 0,

    fn changed(context: ?*anyopaque, kind: cookies.CookieChangeType, cookie: *const cookies.Cookie) void {
        const self: *Records = @ptrCast(@alignCast(context.?));
        self.count += 1;
        if (cookie.secure) self.secure_count += 1;
        if (kind == .deleted) self.deleted_count += 1;
    }
};

test "document-cookie storage reports each Secure mutation once" {
    const allocator = std.testing.allocator;
    var jar = cookies.CookieJar.init(allocator);
    defer jar.deinit();
    var records: Records = .{};
    jar.on_change = .{ .callback = Records.changed, .context = &records };
    const options: cookies.StoreOptions = .{ .is_secure = true, .host = "example.com", .http_only_allowed = false };
    _ = try cookies.parseAndStoreCookie(allocator, &jar, "name=value; Path=/; Secure", "/", options);
    try std.testing.expectEqual(@as(usize, 1), records.count);
    _ = try cookies.parseAndStoreCookie(allocator, &jar, "name=value; Path=/", "/", options);
    try std.testing.expectEqual(@as(usize, 2), records.count);
    try std.testing.expectEqual(@as(usize, 1), records.secure_count);
    try std.testing.expectEqual(@as(usize, 0), records.deleted_count);
    _ = try cookies.parseAndStoreCookie(allocator, &jar, "name=value; Path=/", "/", options);
    try std.testing.expectEqual(@as(usize, 2), records.count);
}
