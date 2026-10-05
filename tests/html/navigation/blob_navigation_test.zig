//! A navigation to a blob: URL (HTML "create navigation params by fetching",
//! Fetch scheme fetch "blob"): the request reads the blob URL store as the
//! environment the navigation fetches for.

const std = @import("std");
const navigation_fetch = @import("html_core").navigation.fetch_integration;

test "navigationRequest - a blob: URL's request reads the store for the environment the URL names" {
    const allocator = std.testing.allocator;
    // Scheme fetch "blob" steps 3-7: a navigation's environment is its
    // reserved client, whose creation URL is the blob URL - of its entry's
    // origin. A frame and a popup both reach the creator's blob, whatever
    // the source document's origin.
    const request = try navigation_fetch.navigationRequest(allocator, "blob:http://web-platform.test:8000/1b4f7c6e-3c1e-4a7e-9a3e-0d2b5c9e8f10", .{ .destination = .iframe });
    defer request.deinit();
    try std.testing.expect(request.origin == .origin);
    try std.testing.expectEqualStrings("http://web-platform.test:8000", request.origin.origin);

    // A blob URL made in an opaque origin: "null" names it, as the store
    // recorded it.
    const opaque_request = try navigation_fetch.navigationRequest(allocator, "blob:null/0e5d8f2a-7b1c-4c3d-8e9f-1a2b3c4d5e6f", .{ .destination = .document });
    defer opaque_request.deinit();
    try std.testing.expect(opaque_request.origin == .origin);
    try std.testing.expectEqualStrings("null", opaque_request.origin.origin);

    // A fragment is not part of the URL the store is keyed by.
    const fragment_request = try navigation_fetch.navigationRequest(allocator, "blob:https://a.test/0e5d8f2a-7b1c-4c3d-8e9f-1a2b3c4d5e6f#x/y", .{});
    defer fragment_request.deinit();
    try std.testing.expectEqualStrings("https://a.test", fragment_request.origin.origin);
}

test "navigationRequest - an http(s) URL's request keeps the client's origin" {
    const allocator = std.testing.allocator;
    const request = try navigation_fetch.navigationRequest(allocator, "http://a.test/next", .{});
    defer request.deinit();
    try std.testing.expect(request.origin == .client);
}
