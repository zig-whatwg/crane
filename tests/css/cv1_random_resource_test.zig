//! Deferred random selection must preserve source ownership without fetching
//! resource candidates before a branch has been selected.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Source = css.style_values.ResourceSource;

const Resolver = struct {
    prefix: []const u8,
    fn resolve(raw_context: *const anyopaque, allocator: std.mem.Allocator, raw: []const u8) ?[]u8 {
        const self: *const @This() = @ptrCast(@alignCast(raw_context));
        if (std.mem.eql(u8, raw, "bad[")) return null;
        return std.mem.concat(allocator, u8, &.{ self.prefix, raw }) catch null;
    }
};

test "random pending URLs keep their source after the resolver and declaration end" {
    try lifetime(testing.allocator);
}

fn lifetime(allocator: std.mem.Allocator) !void {
    const style = blk: {
        const source = try Source.create(allocator, .{ .base_url = "https://original.test/sheet.css", .referrer_policy = "no-referrer" });
        defer source.unref();
        var resolver = Resolver{ .prefix = "https://original.test/" };
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, "background-image:random-item(fixed 0,url(a.png),url(b.png))");
        defer block.deinit();
        var declarations = block.typed();
        const pending = declarations.next() orelse return error.RandomPendingValueNotImplemented;
        try testing.expectEqual(@as(usize, 0), pending.value.value.resourceUrls().len);
        resolver.prefix = "https://changed.test/";
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    const urls = style.get(.background_image).resourceUrls();
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expectEqualStrings("https://original.test/a.png", urls[0].url);
    try testing.expectEqualStrings("https://original.test/sheet.css", urls[0].source.?.base_url);
    try testing.expectEqualStrings("no-referrer", urls[0].source.?.referrer_policy);
    try testing.expect(urls[0].valid);
    try testing.expect(!urls[0].local_fragment);
}

test "random selected empty invalid and fragment URLs preserve their original flags" {
    inline for (.{
        .{ "#paint", true, true },
        .{ "", false, false },
        .{ "bad[", false, false },
    }) |c| {
        var resolver = Resolver{ .prefix = "https://original.test/" };
        const text = try std.fmt.allocPrint(testing.allocator, "background-image:random-item(fixed 0,url(\"{s}\"),none)", .{c[0]});
        defer testing.allocator.free(text);
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, text);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        const urls = style.get(.background_image).resourceUrls();
        try testing.expectEqual(@as(usize, 1), urls.len);
        try testing.expectEqual(c[1], urls[0].valid);
        try testing.expectEqual(c[2], urls[0].local_fragment);
    }
}

test "random pending resource ownership unwinds allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    // The legacy UrlResolver returns nullable text, not an error union.
    // Exercise our owned captures and values without making that unrelated
    // seam's explicit-null failure stand in for an allocation error.
    const source = try Source.create(allocator, .{ .base_url = "https://original.test/sheet.css" });
    defer source.unref();
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator, .resource_source = source }, "background-image:random-item(fixed 0,url(a.png),url(b.png))");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const urls = style.get(.background_image).resourceUrls();
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expectEqualStrings("a.png", urls[0].url);
    try testing.expectEqualStrings("https://original.test/sheet.css", urls[0].source.?.base_url);
}
