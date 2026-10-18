//! HTTP fetch step 3.1's requestForServiceWorker, as the manager copies it
//! for the worker's thread (service_worker.manager.copyRequestForWorker): its
//! URL is the hop the fetch event shows - the request's current URL - and it
//! keeps the redirect-taint the hops before it gave the request, so a
//! passthrough `fetch(event.request)` of a hop after a cross-origin redirect
//! serializes its `Origin` as "null", as the request itself would
//! (navigation-headers.https.html's "POST ... redirect and passthrough
//! service worker" cases; Fetch "serializing a request origin" step 2).

const std = @import("std");
const fetch = @import("fetch");
const sw = @import("service_worker");

const InternalRequest = fetch.internal.InternalRequest;

fn serializedOrigin(request: *const InternalRequest) ![]u8 {
    return request.serializeOrigin(std.testing.allocator);
}

test "a service worker's copy of a hop after a cross-origin redirect keeps the redirect-taint, and so does a clone of it" {
    const allocator = std.testing.allocator;
    // a.test's form posts to b.test, which redirects back to a.test: the
    // last hop is a.test again, but b.test was neither the previous URL's
    // origin nor the request's.
    const request = try InternalRequest.init(allocator, "https://a.test/form-target");
    defer request.deinit();
    try request.setOrigin("https://a.test");
    try request.setMethod("POST");
    try request.addUrl("https://b.test/redirect");
    try request.addUrl("https://a.test/sw-scope");
    {
        const own = try serializedOrigin(request);
        defer allocator.free(own);
        try std.testing.expectEqualStrings("null", own);
    }

    const copy = (try sw.manager.copyRequestForWorker(allocator, request)).?;
    defer copy.deinit();
    // The hop: one URL, the current one.
    try std.testing.expectEqual(@as(usize, 1), copy.url_list.items.len);
    try std.testing.expectEqualStrings("https://a.test/sw-scope", copy.currentUrl());
    const copied = try serializedOrigin(copy);
    defer allocator.free(copied);
    try std.testing.expectEqualStrings("null", copied);

    // new Request(event.request) and fetch(event.request) clone it.
    const cloned = try copy.clone();
    defer cloned.deinit();
    const from_clone = try serializedOrigin(cloned);
    defer allocator.free(from_clone);
    try std.testing.expectEqualStrings("null", from_clone);
}

test "a service worker's copy of a request no redirect tainted serializes its origin" {
    const allocator = std.testing.allocator;
    const request = try InternalRequest.init(allocator, "https://a.test/one");
    defer request.deinit();
    try request.setOrigin("https://a.test");
    // a.test -> b.test: b.test's previous URL was a.test, the request's own
    // origin - still "same-origin".
    try request.addUrl("https://b.test/two");
    const copy = (try sw.manager.copyRequestForWorker(allocator, request)).?;
    defer copy.deinit();
    const copied = try serializedOrigin(copy);
    defer allocator.free(copied);
    try std.testing.expectEqualStrings("https://a.test", copied);
}
