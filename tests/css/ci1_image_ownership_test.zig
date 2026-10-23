//! Owned URL provenance across paint/filter/mask values and computed copies.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn allocationCase(allocator: std.mem.Allocator, name: []const u8, text: []const u8) !void {
    const property = css.properties.lookup(name) orelse return error.ImagePropertyNotImplemented;
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://example.test/sheet.css", .referrer_policy = "no-referrer" });
    defer source.unref();
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator, .resource_source = source }, property, text, &assignments));
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try block.entries.ensureUnusedCapacity(allocator, assignments.items.len);
    for (assignments.items) |a| {
        a.value.retain();
        block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = a.longhand, .value = a.value, .important = false } });
    }
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try block.getPropertyValue(name, &output);
    if (property == .longhand) {
        output.clearRetainingCapacity();
        try style.serializeResolved(property.longhand, &output, allocator);
    }
}

test "paint marker filter and mask cleanup survives every allocation failure" {
    const cases = .{
        .{ "fill", "url(#paint) #00ff00" },
        .{ "marker", "url(marker.svg#m)" },
        .{ "filter", "url(filters.svg#one) drop-shadow(1em 2px 3px #ff0000) blur(2em) url(#local)" },
        .{ "mask", "url(a) right 1em bottom 2em / 3em auto no-repeat, url(b) padding-box alpha" },
        .{ "mask-image", "url(a), none, url(a), url(#local)" },
        .{ "mask-border-slice", "1 2% 3 4% fill" },
        .{ "mask-border-width", "1em 2% auto 3" },
    };
    inline for (cases) |case| try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{ case[0], case[1] });
}

test "computed image values keep ordered resource ranges and the source alive" {
    const property = css.properties.lookup("mask-image") orelse return error.ImagePropertyNotImplemented;
    const source = try css.style_values.ResourceSource.create(testing.allocator, .{ .base_url = "https://example.test/sheet.css", .referrer_policy = "origin" });
    var source_owned = true;
    defer if (source_owned) source.unref();
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator, .resource_source = source }, property, "url(a), none, url(a), url(#local), url('')", &assignments));
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    try block.entries.ensureUnusedCapacity(testing.allocator, 1);
    assignments.items[0].value.retain();
    block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = property.longhand, .value = assignments.items[0].value, .important = false } });
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    for (assignments.items) |a| a.value.release();
    assignments.clearRetainingCapacity();
    block.clear();
    source.unref();
    source_owned = false;
    const value = style.get(property.longhand);
    const urls = value.resourceUrls();
    try testing.expectEqual(@as(usize, 4), urls.len);
    try testing.expectEqualStrings("a", urls[0].url);
    try testing.expectEqualStrings("a", urls[1].url);
    try testing.expect(urls[2].local_fragment);
    try testing.expect(!urls[3].valid);
    var serialized: std.ArrayList(u8) = .empty;
    defer serialized.deinit(testing.allocator);
    try style.serializeResolved(property.longhand, &serialized, testing.allocator);
    for (urls, 0..) |url, i| {
        try testing.expectEqualStrings("origin", url.source.?.referrer_policy);
        try testing.expect(std.mem.startsWith(u8, serialized.items[url.range.start..url.range.end], "url("));
        if (i > 0) try testing.expect(urls[i - 1].range.end < url.range.start);
    }
}
