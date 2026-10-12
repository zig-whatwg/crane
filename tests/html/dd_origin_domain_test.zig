//! HTML 7.1.1: tuple origins and same origin-domain. The origin with its
//! domain is dom.origin_record's record (shared by documents, set by
//! document.domain); the plain tuple origins - html_core.Origin, the
//! navigation's record of a document's origin, and runtime.Origin, an
//! environment's - carry no domain, and no WindowProxy record runs an access
//! check: the engine does [cross_origin_objects].
const std = @import("std");
const html_core = @import("html_core");
const runtime = @import("runtime");

test "the tuple origins carry no domain and no same origin-domain of their own" {
    // Batch 2 of the cross-origin objects work retired them: a copy of a
    // domain could not see a later document.domain set, and nothing set one.
    try std.testing.expect(!@hasField(html_core.Origin, "domain"));
    try std.testing.expect(!@hasDecl(html_core.Origin, "isSameOriginDomain"));
    try std.testing.expect(!@hasField(runtime.Origin, "domain"));
    try std.testing.expect(!@hasDecl(runtime.Origin, "isSameOriginDomain"));
    try std.testing.expect(!@hasDecl(runtime.Origin, "setDomain"));
}

test "the navigation's WindowProxy record runs no access check" {
    try std.testing.expect(!@hasDecl(html_core.WindowProxy, "canAccess"));
    try std.testing.expect(!@hasDecl(html_core.WindowProxy, "isSameOriginAccess"));
    try std.testing.expect(!@hasDecl(html_core.WindowProxy, "accessProperty"));
    try std.testing.expect(!@hasDecl(html_core.WindowProxy, "isCrossOriginAllowedProperty"));
}

fn sameOriginCases(comptime Origin: type) !void {
    const Case = struct { scheme: []const u8 = "https", host: []const u8 = "a.example.test", port: ?u16 = null, same: bool };
    const cases = [_]Case{
        .{ .same = true },
        .{ .port = 8000, .same = false },
        .{ .scheme = "http", .same = false },
        .{ .host = "b.example.test", .same = false },
    };
    const a = Origin.init("https", "a.example.test", null);
    for (cases) |case| {
        const b = Origin.init(case.scheme, case.host, case.port);
        try std.testing.expectEqual(case.same, a.isSameOrigin(b));
        try std.testing.expectEqual(case.same, b.isSameOrigin(a));
    }
    try std.testing.expect(!Origin.createOpaque().isSameOrigin(a));
}

test "window Origin compares scheme, host and port" {
    try sameOriginCases(html_core.Origin);
}

test "environment Origin compares scheme, host and port" {
    try sameOriginCases(runtime.Origin);
}

test "serialized origin-domain comparison keeps ports only before opting in" {
    const origin_domain = @import("html").origin_domain;
    if (comptime !@hasDecl(origin_domain, "sameOriginDomainValues")) return error.MissingOriginDomainComparison;
    const compare = origin_domain.sameOriginDomainValues;
    try std.testing.expect(compare("https://a.example.test:8000", null, "https://a.example.test:8000", null));
    try std.testing.expect(!compare("https://a.example.test:8000", null, "https://a.example.test:8001", null));
    try std.testing.expect(!compare("https://a.example.test:8000", "example.test", "https://a.example.test:8000", null));
    try std.testing.expect(!compare("https://a.example.test:8000", null, "https://a.example.test:8000", "example.test"));
    try std.testing.expect(compare("https://a.example.test:8000", "example.test", "https://b.example.test:8001", "example.test"));
    try std.testing.expect(!compare("http://a.example.test", "example.test", "https://b.example.test", "example.test"));
    try std.testing.expect(!compare("https://a.example.test", "a.example.test", "https://a.example.test", "example.test"));
    // A serialization cannot identify two opaque origins as the same one.
    try std.testing.expect(!compare("null", null, "null", null));
    try std.testing.expect(!compare("null", "example.test", "null", "example.test"));
}
