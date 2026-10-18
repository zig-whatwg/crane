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

test "a service worker's copy keeps what its dropped hops made of Sec-Fetch-Site, and the navigation's user activation" {
    const allocator = std.testing.allocator;
    // navigation-headers.https.html "same-origin with cross-site redirect,
    // same-origin redirect, and passthrough service worker": the frame's
    // navigation went through a cross-site hop before its last, same-origin
    // one; the worker's copy holds the last hop alone.
    const request = try InternalRequest.init(allocator, "https://web-platform.test:8443/redirect.py");
    defer request.deinit();
    try request.setOrigin("https://web-platform.test:8443");
    request.mode = .navigate;
    request.destination = .iframe;
    request.user_activation = true;
    try request.addUrl("https://not-web-platform.test:8443/redirect.py");
    try request.addUrl("https://web-platform.test:8443/navigation-headers-server.py");
    const copy = (try sw.manager.copyRequestForWorker(allocator, request)).?;
    defer copy.deinit();
    try std.testing.expectEqual(@as(usize, 1), copy.url_list.items.len);
    try std.testing.expectEqual(fetch.internal.SiteRelation.cross_site, copy.dropped_urls_site);
    try std.testing.expect(copy.user_activation);
    // fetch(event.request) of it: cross-site, as the request itself.
    const metadata = (try fetch.algorithms.fetch_metadata.headersFor(allocator, fetch.algorithms.fetch_metadata.Input.of(copy))).?;
    try std.testing.expectEqualStrings("cross-site", metadata.site);
    // A same-site hop only: same-site.
    const other = try InternalRequest.init(allocator, "https://web-platform.test:8443/redirect.py");
    defer other.deinit();
    try other.setOrigin("https://web-platform.test:8443");
    try other.addUrl("https://www1.web-platform.test:8443/redirect.py");
    try other.addUrl("https://web-platform.test:8443/target");
    const other_copy = (try sw.manager.copyRequestForWorker(allocator, other)).?;
    defer other_copy.deinit();
    try std.testing.expectEqual(fetch.internal.SiteRelation.same_site, other_copy.dropped_urls_site);
    // A request with no hops: nothing dropped.
    const single = try InternalRequest.init(allocator, "https://web-platform.test:8443/one");
    defer single.deinit();
    try single.setOrigin("https://web-platform.test:8443");
    const single_copy = (try sw.manager.copyRequestForWorker(allocator, single)).?;
    defer single_copy.deinit();
    try std.testing.expectEqual(fetch.internal.SiteRelation.same_origin, single_copy.dropped_urls_site);
}
