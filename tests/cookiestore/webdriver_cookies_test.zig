//! WebDriver's cookie commands over the jar (WebDriver 14): "all associated
//! cookies" of a document, and "delete cookies" - what the WPT runner's
//! testdriver answers test_driver.get_all_cookies / get_named_cookie /
//! delete_all_cookies with.

const std = @import("std");
const cookiestore = @import("cookiestore");

const CookieJar = cookiestore.CookieJar;

const from_https: cookiestore.StoreOptions = .{ .is_secure = true, .host = "web-platform.test", .http_only_allowed = true };

fn store(jar: *CookieJar, header: []const u8, path: []const u8) !void {
    _ = try cookiestore.parseAndStoreCookie(std.testing.allocator, jar, header, path, from_https);
}

fn freeAll(list: *std.ArrayListUnmanaged(cookiestore.Cookie)) void {
    for (list.items) |*c| c.deinit();
    list.deinit(std.testing.allocator);
}

fn names(list: []const cookiestore.Cookie, buffer: []u8) []const u8 {
    var w: std.Io.Writer = .fixed(buffer);
    for (list, 0..) |c, i| {
        if (i > 0) w.writeByte(',') catch break;
        w.writeAll(c.name) catch break;
    }
    return w.buffered();
}

test "associated cookies: the HTTP API's selection - HttpOnly included, other hosts, paths and insecure documents not" {
    var jar = CookieJar.init(std.testing.allocator);
    defer jar.deinit();
    try store(&jar, "plain=1; Path=/", "/");
    try store(&jar, "hidden=2; Path=/; HttpOnly", "/");
    try store(&jar, "safe=3; Path=/; Secure", "/");
    try store(&jar, "deep=4; Path=/cookies/sub", "/cookies/sub/x");
    try store(&jar, "lax=5; Path=/; SameSite=Strict", "/");
    _ = try cookiestore.parseAndStoreCookie(std.testing.allocator, &jar, "other=6; Path=/", "/", .{ .is_secure = true, .host = "not-web-platform.test", .http_only_allowed = true });

    var buffer: [128]u8 = undefined;
    // An https document at /cookies/: every cookie of its host whose path it
    // path-matches, HttpOnly and SameSite=Strict included (no same-site filter).
    var https = try cookiestore.webdriverAssociatedCookies(&jar, "https://web-platform.test:8443/cookies/attributes/x.html", null);
    defer freeAll(&https);
    try std.testing.expectEqualStrings("plain,hidden,safe,lax", names(https.items, &buffer));

    // An http document: no Secure cookie.
    var http = try cookiestore.webdriverAssociatedCookies(&jar, "http://web-platform.test:8000/cookies/sub/page.html", null);
    defer freeAll(&http);
    try std.testing.expectEqualStrings("deep,plain,hidden,lax", names(http.items, &buffer));

    // By name.
    var one = try cookiestore.webdriverAssociatedCookies(&jar, "https://web-platform.test/", "hidden");
    defer freeAll(&one);
    try std.testing.expectEqual(@as(usize, 1), one.items.len);
    try std.testing.expect(one.items[0].http_only);

    // A URL cookies are not kept for has none.
    var none = try cookiestore.webdriverAssociatedCookies(&jar, "about:blank", null);
    defer freeAll(&none);
    try std.testing.expectEqual(@as(usize, 0), none.items.len);
}

const Recorder = struct {
    deleted: usize = 0,
    fn hook(context: ?*anyopaque, change_type: cookiestore.CookieChangeType, cookie: *const cookiestore.Cookie) void {
        _ = cookie;
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        if (change_type == .deleted) self.deleted += 1;
    }
};

test "delete cookies: expires the document's associated cookies, by name or all, and reports each deleted" {
    var jar = CookieJar.init(std.testing.allocator);
    defer jar.deinit();
    var recorder: Recorder = .{};
    jar.on_change = .{ .callback = Recorder.hook, .context = &recorder };
    try store(&jar, "a=1; Path=/", "/");
    try store(&jar, "b=2; Path=/; HttpOnly", "/");
    try store(&jar, "c=3; Path=/elsewhere", "/elsewhere/x");
    _ = try cookiestore.parseAndStoreCookie(std.testing.allocator, &jar, "d=4; Path=/", "/", .{ .is_secure = true, .host = "www1.web-platform.test", .http_only_allowed = true });

    const url = "https://web-platform.test/cookies/x.html";
    try std.testing.expectEqual(@as(usize, 1), cookiestore.webdriverDeleteCookies(&jar, url, "b"));
    try std.testing.expectEqual(@as(usize, 1), recorder.deleted);

    // All of them: only those associated with the document go.
    try std.testing.expectEqual(@as(usize, 1), cookiestore.webdriverDeleteCookies(&jar, url, null));
    try std.testing.expectEqual(@as(usize, 2), recorder.deleted);
    var buffer: [64]u8 = undefined;
    var left = try cookiestore.webdriverAssociatedCookies(&jar, "https://web-platform.test/elsewhere/", null);
    defer freeAll(&left);
    try std.testing.expectEqualStrings("c", names(left.items, &buffer));
    try std.testing.expectEqual(@as(usize, 2), jar.count());
}
