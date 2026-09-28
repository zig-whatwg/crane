//! Origins as Fetch compares them: a URL's origin, serialized (HTML
//! "serialization of an origin"), and "same origin" between two of them.
//!
//! A request's origin reaches Fetch from its client as a serialized origin
//! ("https://example.com:8443", or "null" for an opaque one); some callers
//! still hand over a whole URL. Either way it is normalized by parsing it and
//! taking its origin, so "https://example.com:443" and
//! "https://example.com/path" compare as the same origin.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin

const std = @import("std");
const basic_parser = @import("basic_parser");
const url_origin = @import("origin");

const Allocator = std.mem.Allocator;

/// The serialization of `url`'s origin: "scheme://host[:port]" for a tuple
/// origin (a default port omitted), "null" for an opaque origin or a string
/// that is not a URL. OWNED.
pub fn serializedOriginOf(allocator: Allocator, url: []const u8) ![]u8 {
    var record = basic_parser.parse(allocator, url, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return allocator.dupe(u8, "null"),
    };
    defer record.deinit();
    // A special URL always has a host; a failure here is a URL that is not
    // one, and its origin is opaque.
    var origin = url_origin.getOrigin(allocator, &record) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return allocator.dupe(u8, "null"),
    };
    defer origin.deinit(allocator);
    return origin.serialize(allocator);
}

/// HTML "same origin" for two URLs or serialized origins: their origins are
/// the same tuple. An opaque origin is same origin with nothing here: a
/// serialized "null" cannot say which opaque origin it was.
pub fn sameOrigin(allocator: Allocator, a: []const u8, b: []const u8) !bool {
    const origin_a = try serializedOriginOf(allocator, a);
    defer allocator.free(origin_a);
    if (std.mem.eql(u8, origin_a, "null")) return false;
    const origin_b = try serializedOriginOf(allocator, b);
    defer allocator.free(origin_b);
    return std.mem.eql(u8, origin_a, origin_b);
}

test "a URL's origin, serialized" {
    const allocator = std.testing.allocator;
    const cases = [_][2][]const u8{
        .{ "https://example.com/path?q#f", "https://example.com" },
        .{ "https://example.com:443/", "https://example.com" },
        .{ "http://Example.COM:8000/x", "http://example.com:8000" },
        .{ "http://example.com:8000", "http://example.com:8000" },
        .{ "data:text/plain,hi", "null" },
        .{ "null", "null" },
        .{ "", "null" },
    };
    for (cases) |case| {
        const serialized = try serializedOriginOf(allocator, case[0]);
        defer allocator.free(serialized);
        try std.testing.expectEqualStrings(case[1], serialized);
    }
}

test "same origin compares scheme, host and port, and nothing opaque is" {
    const allocator = std.testing.allocator;
    try std.testing.expect(try sameOrigin(allocator, "http://a.test:8000/x", "http://a.test:8000"));
    try std.testing.expect(try sameOrigin(allocator, "https://a.test/", "https://a.test:443/y"));
    try std.testing.expect(!try sameOrigin(allocator, "http://a.test:8000/", "http://a.test:8001/"));
    try std.testing.expect(!try sameOrigin(allocator, "http://a.test/", "https://a.test/"));
    try std.testing.expect(!try sameOrigin(allocator, "http://a.test/", "http://www.a.test/"));
    try std.testing.expect(!try sameOrigin(allocator, "null", "null"));
    try std.testing.expect(!try sameOrigin(allocator, "data:,x", "data:,x"));
}
