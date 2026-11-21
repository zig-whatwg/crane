//! Lane maj5: HTML "create navigation params by fetching" step 9 - "If
//! sourceSnapshotParams's has transient activation is true, then set
//! request's user-activation to true" - which Fetch Metadata turns into
//! `Sec-Fetch-User: ?1` (Chrome and Firefox:
//! fetch/metadata/window-open.https.sub.html, generated/element-*.html,
//! form-submission.https.sub.html).

const std = @import("std");
const html_core = @import("html_core");
const fetch = @import("fetch");
const navigation_fetch = html_core.navigation.fetch_integration;

test "a navigation request takes the source snapshot's transient activation as its user-activation" {
    const allocator = std.testing.allocator;
    const activated = try navigation_fetch.navigationRequest(allocator, "https://a.test/page", .{ .destination = .iframe, .user_activation = true });
    defer activated.deinit();
    try std.testing.expect(activated.user_activation);
    const plain = try navigation_fetch.navigationRequest(allocator, "https://a.test/page", .{ .destination = .iframe });
    defer plain.deinit();
    try std.testing.expect(!plain.user_activation);
}

test "Fetch Metadata sends Sec-Fetch-User for a user-activated navigation request only" {
    const allocator = std.testing.allocator;
    const metadata = fetch.algorithms.fetch_metadata;
    const url_list = [_][]const u8{"https://a.test/page"};
    const activated = (try metadata.headersFor(allocator, .{ .url_list = &url_list, .destination = .iframe, .mode = .navigate, .origin = .client, .user_activation = true })).?;
    try std.testing.expectEqualStrings("?1", activated.user.?);
    const plain = (try metadata.headersFor(allocator, .{ .url_list = &url_list, .destination = .iframe, .mode = .navigate, .origin = .client, .user_activation = false })).?;
    try std.testing.expect(plain.user == null);
}
