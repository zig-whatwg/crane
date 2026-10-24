//! Q22/Q29: generated-content images use the backing allocator and own references.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Content = css.style_values.Content;
const Item = std.meta.Child(@TypeOf(@as(Content, undefined).items));

fn parseContent(allocator: std.mem.Allocator, text: []const u8, source: ?*css.style_values.ResourceSource) !*Content {
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator, .resource_source = source }, .{ .longhand = .content }, text, &assignments));
    const result = assignments.items[0].value.value.content;
    result.ref();
    return result;
}

const Checks = if (@hasField(Item, "image")) struct {
    fn retainedPastContent(allocator: std.mem.Allocator) !void {
        const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://example.test/sheet.css", .referrer_policy = "no-referrer" });
        var source_owned = true;
        defer if (source_owned) source.unref();
        const original = try parseContent(allocator, "light-dark(url(light), url(dark))", source);
        var original_owned = true;
        defer if (original_owned) original.unref();
        const image = original.items[0].image.?;
        image.retain();
        defer image.release();
        original.unref();
        original_owned = false;
        source.unref();
        source_owned = false;
        const urls = image.resourceUrls();
        try testing.expectEqual(@as(usize, 2), urls.len);
        try testing.expectEqualStrings("light", urls[0].url);
        try testing.expectEqualStrings("dark", urls[1].url);
        try testing.expectEqualStrings("https://example.test/sheet.css", urls[0].source.?.base_url);
        try testing.expectEqualStrings("no-referrer", urls[1].source.?.referrer_policy);
    }

    fn attrCopy(allocator: std.mem.Allocator, release_source_first: bool) !void {
        const original = try parseContent(allocator, "url(image) attr(data, 'fallback')", null);
        var original_owned = true;
        defer if (original_owned) original.unref();
        const computed = (try original.compute(allocator, null)).?;
        var computed_owned = true;
        defer if (computed_owned) computed.unref();
        const survivor = if (release_source_first) blk: {
            original.unref();
            original_owned = false;
            break :blk computed;
        } else blk: {
            computed.unref();
            computed_owned = false;
            break :blk original;
        };
        try testing.expectEqualStrings("image", survivor.items[0].image.?.resourceUrls()[0].url);
        try testing.expectEqualStrings("image", survivor.items[0].resource_urls[0].url);
        if (release_source_first) try testing.expectEqualStrings("fallback", survivor.items[1].text);
    }
} else struct {};

test "a typed image retained from content survives the content and its resource source" {
    if (comptime !@hasField(Item, "image")) return error.TypedContentImagesNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.retainedPastContent, .{});
}

test "attr computation retains typed images in either release order and at every allocation failure" {
    if (comptime !@hasField(Item, "image")) return error.TypedContentImagesNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.attrCopy, .{true});
    try testing.checkAllAllocationFailures(testing.allocator, Checks.attrCopy, .{false});
}

test "raw content gradients keep Syntax EOF completion before strict gradient parsing" {
    const content = try parseContent(testing.allocator, "linear-gradient(red, blue", null);
    defer content.unref();
    try testing.expectEqualStrings("linear-gradient(red, blue)", content.serialization);
    for ([_][]const u8{ "linear-gradient(red; blue)", "linear-gradient(red { blue)", "linear-gradient(red, url(bad name))" }) |input| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (assignments.items) |item| item.value.release();
            assignments.deinit(testing.allocator);
        }
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = .content }, input, &assignments));
    }
}

test "content equality preserves omitted versus explicit image resolution" {
    if (comptime !@hasField(Item, "image")) return error.TypedContentImagesNotImplemented;
    const omitted = try parseContent(testing.allocator, "image-set(url(a))", null);
    defer omitted.unref();
    const explicit = try parseContent(testing.allocator, "image-set(url(a) 1x)", null);
    defer explicit.unref();
    const equal = try parseContent(testing.allocator, "image-set(url(a))", null);
    defer equal.unref();
    try testing.expectEqualStrings(omitted.serialization, explicit.serialization);
    try testing.expect(!omitted.eql(explicit));
    try testing.expect(omitted.eql(equal));
}

fn symbolsOwnership(allocator: std.mem.Allocator) !void {
    const content = try parseContent(allocator, "counter(name, symbols(image-set(url(a) 1x)))", null);
    defer content.unref();
    try testing.expectEqualStrings("counter(name, symbols(image-set(url(\"a\") 1x)))", content.serialization);
    try testing.expectEqual(@as(usize, 1), content.resource_urls.len);
    try testing.expectEqualStrings("a", content.resource_urls[0].url);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator }, .{ .longhand = .content }, "counter(name, symbols(numeric image-set(url(a) 1x)))", &assignments));
    try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

test "symbols releases each temporary typed image on success rejection and allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, symbolsOwnership, .{});
}
