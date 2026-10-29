//! Q87/Q88: one native URL image uses the existing Content owner.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Value = css.style_values.Value;
const Content = @typeInfo(@FieldType(Value, "content")).pointer.child;
const Item = @typeInfo(@FieldType(Content, "items")).pointer.child;

test "Q88 measures Content and Item before the cold constructor" {
    std.debug.print("om1 content layout: Content={d} Item={d}\n", .{ @sizeOf(Content), @sizeOf(Item) });
    // Local BASE receipt2026-10-27: Content120, Item96; no product edit.
    const base_content: usize = 120;
    const base_item: usize = 96;
    try std.testing.expectEqual(base_content, @sizeOf(Content));
    try std.testing.expectEqual(base_item, @sizeOf(Item));
}

fn owned(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(Content, "fromImage")) return std.testing.expect(false);
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://om1.test/style.css", .referrer_policy = "no-referrer", .origin_clean = false });
    var source_owned = true;
    defer if (source_owned) source.unref();
    var assigned: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assigned.items) |item| item.value.release();
        assigned.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator, .resource_source = source }, .{ .longhand = .list_style_image }, "url(a.png)", &assigned));
    const content = (try Content.fromImage(allocator, assigned.items[0].value.value)) orelse return error.TestExpectedValue;
    defer content.unref();
    for (assigned.items) |item| item.value.release();
    assigned.clearRetainingCapacity();
    source.unref();
    source_owned = false;
    try std.testing.expectEqual(@as(usize, 1), content.items.len);
    try std.testing.expect(content.alternate == null);
    try std.testing.expect(content.items[0].kind == .image);
    try std.testing.expect(content.items[0].image != null);
    try std.testing.expectEqualStrings("url(\"a.png\")", content.serialization);
    try std.testing.expectEqual(@as(usize, 1), content.resource_urls.len);
    try std.testing.expect(content.resource_urls[0].source.? == source);
    try std.testing.expectEqualStrings("https://om1.test/style.css", source.base_url);
    try std.testing.expectEqualStrings("no-referrer", source.referrer_policy);
    try std.testing.expect(!source.origin_clean);
}

test "Q88 native content owns its image and provenance after input owners disappear" {
    try std.testing.checkAllAllocationFailures(a, owned, .{});
}

test "Q88 native content rejects non-image values without allocating a fake representation" {
    if (comptime !@hasDecl(Content, "fromImage")) return std.testing.expect(false);
    try std.testing.expect(try Content.fromImage(a, .{ .number = 2 }) == null);
    try std.testing.expect(try Content.fromImage(a, Value.kw(.none)) == null);
}

test "Q88 ordinary content text and resource serialization remain unchanged" {
    const cases = .{
        .{ "url(a.png)", "url(\"a.png\")" },
        .{ "'before' url(a.png) 'after'", "\"before\" url(\"a.png\") \"after\"" },
        .{ "url(a.png) / 'alt'", "url(\"a.png\") / \"alt\"" },
        .{ "counter(section) '. '", "counter(section) \". \"" },
    };
    inline for (cases) |case| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = a }, "content: " ++ case[0]);
        defer block.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(a);
        try block.getPropertyValue("content", &out);
        try std.testing.expectEqualStrings(case[1], out.items);
    }
}
