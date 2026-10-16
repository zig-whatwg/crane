const std = @import("std");
const csp = @import("csp");

fn parse(allocator: std.mem.Allocator) !void {
    var policy = try csp.parseSerializedCSP(allocator, "script-src https: https://example.test/a 'nonce-abc' 'sha256-YWJj'; img-src 'none'", .header, .enforce);
    defer policy.deinit();
}

test "CSP source parsing unwinds each partially constructed expression" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parse, .{});
}

fn makeOrigin(allocator: std.mem.Allocator) !void {
    var origin = try csp.Origin.create(allocator, "https", "child.test", 443);
    defer origin.deinit();
}

test "CSP self-origin construction releases the scheme if copying the host fails" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, makeOrigin, .{});
}
