//! A navigation request carries the navigable's cookie jar, and includes
//! credentials (src/html/navigation/fetch_integration.zig). html_core's own
//! test blocks run under no test target, so the case lives here.

const std = @import("std");
const html_core = @import("html_core");
const navigation_fetch = html_core.navigation.fetch_integration;
/// cookiestore's CookieJar, reached through the option that takes one.
const CookieJar = std.meta.Child(std.meta.Child(@FieldType(navigation_fetch.NavigationFetchOptions, "cookie_jar")));

test "a navigation request takes the jar it is given, and includes credentials" {
    const allocator = std.testing.allocator;
    var jar = CookieJar.init(allocator);
    defer jar.deinit();

    const request = try navigation_fetch.navigationRequest(allocator, "http://a.test/page", .{ .cookie_jar = &jar });
    defer request.deinit();
    try std.testing.expect(request.cookie_jar == &jar);
    try std.testing.expect(request.credentials_mode == .include);

    const without = try navigation_fetch.navigationRequest(allocator, "http://a.test/page", .{});
    defer without.deinit();
    try std.testing.expect(without.cookie_jar == null);
}
