//! Values 5 §8.7.2 and Properties and Values API 1 §2.4: the
//! registration's grammar consumes the substituted value WITH its taint.
const std = @import("std");
const css = @import("css");
const support = @import("vars2_support.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const initial_url = "url(\"https://example.test/initial.png\")";
const target_url = "url(\"https://example.test/private.png\")";

fn attribute(_: *const anyopaque, name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, name, "data-name")) return "--image";
    if (std.mem.eql(u8, name, "data-url")) return "https://example.test/private.png";
    if (std.mem.eql(u8, name, "data-length")) return "12";
    if (std.mem.eql(u8, name, "data-mime")) return "image/png";
    return null;
}

fn check(allocator: Allocator, text: []const u8, name: []const u8, expected: []const u8, tainted: bool) !void {
    const registry = try support.snapshotOf(allocator, .{}, &.{
        .{ .name = "--registered-url", .syntax = "<url>", .inherits = false, .initial = initial_url },
        .{ .name = "--registered-image", .syntax = "<image>", .inherits = false, .initial = initial_url },
        .{ .name = "--registered-string", .syntax = "<string>", .inherits = false, .initial = "\"initial\"" },
        .{ .name = "--registered-length", .syntax = "<length>", .inherits = false, .initial = "0px" },
    });
    defer registry.release();
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://example.test/sheet.css" });
    defer source.unref();
    {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .resource_source = source }, text);
        defer block.deinit();
        const context: u8 = 0;
        const style = try css.cascade.cascade(.{
            .allocator = allocator,
            .parent = null,
            .is_root = true,
            .registered = registry,
            .content_attributes = .{ .context = &context, .get = attribute },
        }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        try support.expectCustom(style, name, expected);
        try testing.expectEqual(tainted, style.customValue(name).?.taint.len != 0);
    }
    try testing.expectEqual(@as(u32, 1), source.refs.load(.monotonic));
}

fn rejectedUrl(allocator: Allocator) !void {
    try check(allocator, "--image:" ++ target_url ++ ";--registered-url:var(attr(data-name type(*)))", "--registered-url", initial_url, false);
}

test "registered attr taint: a tainted var name invalidates a URL before computing it" {
    try rejectedUrl(testing.allocator);
}

test "registered attr taint: an image-set string is a URL grammar position" {
    try check(testing.allocator, "--registered-image:image-set(attr(data-url))", "--registered-image", initial_url, false);
}

test "registered attr taint: untainted URL and tainted non-URL values stay valid" {
    try check(testing.allocator, "--image:" ++ target_url ++ ";--name:--image;--registered-url:var(var(--name))", "--registered-url", target_url, false);
    try check(testing.allocator, "--registered-url:" ++ target_url, "--registered-url", target_url, false);
    try check(testing.allocator, "--registered-string:attr(data-url)", "--registered-string", "\"https://example.test/private.png\"", true);
    try check(testing.allocator, "--registered-length:attr(data-length px)", "--registered-length", "12px", true);
}

test "registered attr taint: a type string does not invalidate its sibling URL" {
    try check(testing.allocator, "--registered-image:image-set(\"literal.png\" 1x type(attr(data-mime)))", "--registered-image", "image-set(url(\"literal.png\") 1dppx type(\"image/png\"))", true);
}

test "registered attr taint: source holds and allocations are released on IACVT and OOM" {
    try testing.checkAllAllocationFailures(testing.allocator, rejectedUrl, .{});
}
