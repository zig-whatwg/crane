//! Protocol classification uses the compiled component, not literal comparison.
const std = @import("std");
const up = @import("urlpattern");
const harness = @import("urlpattern_realm.zig");
const A = std.testing.allocator;

test "URLPattern constructor parser checks wildcard protocols for special schemes" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    const init = try up.parseConstructorString(A, realm, "*:?query");
    try std.testing.expectEqualStrings("*", init.protocol.?);
    try std.testing.expectEqualStrings("", init.hostname.?);
    try std.testing.expectEqualStrings("/", init.pathname.?);
    try std.testing.expectEqualStrings("query", init.search.?);
}

test "URLPattern compiles special pathname rules when a protocol pattern matches a special scheme" {
    const page = try harness.Page.open();
    defer page.close();
    const realm = page.realm;
    var pattern = try up.URLPattern.create(A, realm, .{ .init = .{ .protocol = "http*", .pathname = "/a/../b" } }, .{});
    defer pattern.deinit(A);
    try std.testing.expectEqualStrings("/b", pattern.pathname.pattern_string);
}
