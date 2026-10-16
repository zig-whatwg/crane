const std = @import("std");
const fetch = @import("fetch");
const Container = fetch.internal.PolicyContainer;

test "required CSP defaults null and a clone copies enforced policies, not required CSP" {
    const a = std.testing.allocator;
    var empty = Container.init(a);
    defer empty.deinit();
    try std.testing.expect(empty.required_csp == null);
    var empty_copy = try empty.clone(a);
    defer empty_copy.deinit();
    try std.testing.expect(empty_copy.required_csp == null);
    var bytes = "img-src 'none'".*;
    var original = try Container.fromResponseHeaders(a, .{ .url = "https://child.test/", .required_csp = &bytes });
    defer original.deinit();
    bytes[0] = 'x';
    try std.testing.expectEqualStrings("img-src 'none'", original.required_csp.?);
    var copy = try original.clone(a);
    defer copy.deinit();
    try std.testing.expect(copy.required_csp == null);
    try std.testing.expect(copy.csp_list.policies.items[0].containsDirective("img-src"));
}

test "a subsuming response is not intersected with the embedder's nonce" {
    var container = try Container.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://child.test/",
        .csp = "script-src 'nonce-response'",
        .required_csp = "script-src 'nonce-embedder'",
    });
    defer container.deinit();
    try std.testing.expectEqual(@as(usize, 1), container.csp_list.policies.items.len);
    try std.testing.expectEqualStrings("script-src 'nonce-embedder'", container.required_csp.?);
}

test "blanket acceptance enforces both the required and response nonce policies" {
    var container = try Container.fromResponseHeaders(std.testing.allocator, .{
        .url = "https://child.test/",
        .csp = "script-src 'nonce-response'",
        .required_csp = "script-src 'nonce-embedder'",
        .blanket_csp_acceptance = true,
    });
    defer container.deinit();
    try std.testing.expectEqual(@as(usize, 2), container.csp_list.policies.items.len);
}

fn make(allocator: std.mem.Allocator) !void {
    var container = try Container.fromResponseHeaders(allocator, .{
        .url = "https://child.test/",
        .csp = "style-src 'none'",
        .required_csp = "img-src 'none'",
    });
    defer container.deinit();
    var copy = try container.clone(allocator);
    defer copy.deinit();
}

test "required CSP and the appended parsed policy unwind allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, make, .{});
}
