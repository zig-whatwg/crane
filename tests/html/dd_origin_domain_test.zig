//! HTML 7.1.1: tuple origins, document.domain, and same origin-domain.
const std = @import("std");
const html_core = @import("html_core");
const runtime = @import("runtime");

fn defaults(comptime Origin: type) !void {
    const origin = Origin.init("https", "example.test", null);
    if (comptime @hasField(Origin, "domain")) {
        try std.testing.expectEqual(@as(?[]const u8, null), origin.domain);
    } else return error.MissingOriginDomain;
    try std.testing.expect(origin.isSameOriginDomain(origin));
}

fn comparisons(comptime Origin: type) !void {
    if (comptime !@hasField(Origin, "domain")) return error.MissingOriginDomain;
    const Case = struct {
        host: []const u8 = "a.example.test",
        scheme: []const u8 = "https",
        port: ?u16 = null,
        a_domain: ?[]const u8 = null,
        b_domain: ?[]const u8 = null,
        same_origin: bool = true,
        same_origin_domain: bool = true,
    };
    const cases = [_]Case{
        .{},
        .{ .port = 8000, .same_origin = false, .same_origin_domain = false },
        .{ .a_domain = "a.example.test", .same_origin_domain = false },
        .{ .b_domain = "a.example.test", .same_origin_domain = false },
        .{ .a_domain = "a.example.test", .b_domain = "a.example.test" },
        .{ .a_domain = "example.test", .b_domain = "a.example.test", .same_origin_domain = false },
        .{ .host = "b.example.test", .a_domain = "example.test", .b_domain = "example.test", .same_origin = false },
        .{ .host = "b.example.test", .port = 8000, .a_domain = "example.test", .b_domain = "example.test", .same_origin = false },
        .{ .scheme = "http", .a_domain = "example.test", .b_domain = "example.test", .same_origin = false, .same_origin_domain = false },
        .{ .host = "b.example.test", .same_origin = false, .same_origin_domain = false },
    };
    for (cases) |case| {
        var a = Origin.init("https", "a.example.test", null);
        a.domain = case.a_domain;
        var b = Origin.init(case.scheme, case.host, case.port);
        b.domain = case.b_domain;
        try std.testing.expectEqual(case.same_origin, a.isSameOrigin(b));
        try std.testing.expectEqual(case.same_origin_domain, a.isSameOriginDomain(b));
        try std.testing.expectEqual(case.same_origin_domain, b.isSameOriginDomain(a));
    }
    var opaque_origin = Origin.createOpaque();
    opaque_origin.domain = "example.test";
    var tuple = Origin.init("https", "a.example.test", null);
    tuple.domain = "example.test";
    try std.testing.expect(!opaque_origin.isSameOriginDomain(tuple));
    try std.testing.expect(!tuple.isSameOriginDomain(opaque_origin));
}

test "window Origin defaults to an unset domain" {
    try defaults(html_core.Origin);
}

test "environment Origin defaults to an unset domain" {
    try defaults(runtime.Origin);
}

test "window Origin distinguishes same origin from same origin-domain" {
    try comparisons(html_core.Origin);
}

test "environment Origin distinguishes same origin from same origin-domain" {
    try comparisons(runtime.Origin);
}

test "WindowProxy requires both documents to opt in and then ignores ports" {
    const Origin = html_core.Origin;
    if (comptime !@hasField(Origin, "domain")) return error.MissingOriginDomain;
    const context = try html_core.BrowsingContext.initTopLevel(std.testing.allocator);
    defer context.deinit();
    var proxy = html_core.WindowProxy.init(std.testing.allocator, context);
    var target = Origin.init("https", "example.test", null);
    const accessor = target;
    target.domain = "example.test";
    proxy.setDocumentOrigin(target);
    try std.testing.expect(!proxy.isSameOriginAccess(accessor));
    try std.testing.expectError(error.SecurityError, proxy.accessProperty(accessor, "document"));
    try proxy.accessProperty(accessor, "postMessage");
    var relaxed = Origin.init("https", "sub.example.test", 8000);
    relaxed.domain = "example.test";
    try std.testing.expect(proxy.isSameOriginAccess(relaxed));
    try proxy.accessProperty(relaxed, "document");
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

test "an environment origin borrows its domain and serialization ignores it" {
    const Origin = runtime.Origin;
    if (comptime !@hasField(Origin, "domain")) return error.MissingOriginDomain;
    const allocator = std.testing.allocator;
    const domain = try allocator.dupe(u8, "example.test");
    defer allocator.free(domain);
    var origin = try Origin.initOwned(allocator, "https", "sub.example.test", 8000);
    defer origin.deinit();
    origin.domain = domain;
    const serialized = try origin.serialize(allocator);
    defer allocator.free(serialized);
    try std.testing.expectEqualStrings("https://sub.example.test:8000", serialized);
}
