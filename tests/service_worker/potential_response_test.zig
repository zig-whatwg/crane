//! respondWith() step 10.2.4's potentialResponse (service_worker.fetch_event
//! .potentialResponse): a copy of the Response object's response but its
//! body - for an opaque one, its internal response's fields, marked opaque,
//! so a script element or a cache behind the service worker gets the
//! network's status and headers as it would without one.

const std = @import("std");
const fetch = @import("fetch");
const sw = @import("service_worker");

const InternalResponse = fetch.internal.InternalResponse;
const Body = fetch.internal.Body;

fn opaqueResponse(allocator: std.mem.Allocator) !*InternalResponse {
    const response = try InternalResponse.init(allocator);
    errdefer response.deinit();
    response.response_type = .@"opaque";
    try response.addUrl("https://b.test/x.js");
    try response.header_list.append("Content-Type", "text/javascript");
    response.body = try Body.fromBytes(allocator, "f()");
    // As fetch() makes a Response object's response.
    try response.filter();
    return response;
}

test "an opaque Response object's potential response carries its internal response's fields, marked opaque" {
    const allocator = std.testing.allocator;
    const inner = try opaqueResponse(allocator);
    defer inner.deinit();
    const copy = try sw.fetch_event.potentialResponse(allocator, inner);
    defer copy.deinit();
    try std.testing.expectEqual(fetch.internal.ResponseType.@"opaque", copy.response_type);
    try std.testing.expectEqual(@as(u16, 200), copy.status);
    try std.testing.expect(copy.header_list.contains("Content-Type"));
    try std.testing.expectEqualStrings("https://b.test/x.js", copy.url().?);
    // "but its body": the body crosses through the relay.
    try std.testing.expect(copy.body == null);
    try std.testing.expect(copy.internal == null);
    // The Response object's own response is untouched.
    try std.testing.expectEqual(@as(u16, 0), inner.status);
    try std.testing.expectEqualStrings("f()", inner.internal.?.body.?.getBytes());
}

test "a basic Response object's potential response is a copy of it" {
    const allocator = std.testing.allocator;
    const inner = try InternalResponse.init(allocator);
    defer inner.deinit();
    inner.response_type = .basic;
    inner.status = 404;
    try inner.addUrl("https://a.test/missing");
    inner.body = try Body.fromBytes(allocator, "nope");
    const copy = try sw.fetch_event.potentialResponse(allocator, inner);
    defer copy.deinit();
    try std.testing.expectEqual(fetch.internal.ResponseType.basic, copy.response_type);
    try std.testing.expectEqual(@as(u16, 404), copy.status);
    try std.testing.expectEqualStrings("https://a.test/missing", copy.url().?);
    try std.testing.expect(copy.body == null);
}

test "an opaque response with no internal response is copied as it is" {
    const allocator = std.testing.allocator;
    const inner = try InternalResponse.init(allocator);
    defer inner.deinit();
    inner.response_type = .@"opaque";
    inner.applyFilter();
    const copy = try sw.fetch_event.potentialResponse(allocator, inner);
    defer copy.deinit();
    try std.testing.expectEqual(@as(u16, 0), copy.status);
    try std.testing.expectEqual(fetch.internal.ResponseType.@"opaque", copy.response_type);
}
