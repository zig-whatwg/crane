//! Values 5 §8.7.2: URL strings are grammar positions, not every string.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "attr resource collection: image source position and optional direction" {
    const cases = [_]struct { text: []const u8, urls: []const []const u8 }{
        .{ .text = "image(\"one.png\", red)", .urls = &.{"one.png"} },
        .{ .text = "image(ltr /* source */ \"one.png\", red)", .urls = &.{"one.png"} },
        .{ .text = "image(rtl \"one.png\", red)", .urls = &.{"one.png"} },
        .{ .text = "image(red)", .urls = &.{} },
        .{ .text = "image(red, \"not-a-source\")", .urls = &.{} },
        .{ .text = "image(ltr rtl \"not-a-source\")", .urls = &.{} },
        .{ .text = "image(type(\"not-a-source\"), red)", .urls = &.{} },
        .{ .text = "image(url(one.png), \"not-a-source\")", .urls = &.{"one.png"} },
        .{ .text = "image-set(image(\"one.png\", red) 1x, \"two.png\" 2x type(\"image/png\"))", .urls = &.{ "one.png", "two.png" } },
    };
    for (cases) |case| {
        var stream = css.properties.Stream.init(case.text);
        const value = try css.properties.parseLonghand(.{ .allocator = testing.allocator }, .background_image, &stream) orelse return error.ExpectedImage;
        defer value.release();
        try testing.expect(stream.atEnd());
        var serialized: std.ArrayList(u8) = .empty;
        defer serialized.deinit(testing.allocator);
        try css.properties.serializeValue(.background_image, value, &serialized, testing.allocator);
        const urls = value.resourceUrls();
        try testing.expectEqual(case.urls.len, urls.len);
        for (urls, case.urls) |url, expected| {
            try testing.expectEqualStrings(expected, url.url);
            try testing.expect(url.range.start < url.range.end);
            try testing.expect(url.range.end <= serialized.items.len);
        }
    }
}

test "attr content offsets: trivia and unquoted URL opener retain taint" {
    const text = "  /* before */ url(private.png)";
    const start = std.mem.indexOf(u8, text, "url(").?;
    const ranges = [_]css.substitution.TaintRange{.{ .start = start, .end = start + 4, .kind = .container }};
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = .content }, text, &assignments));
    for (assignments.items) |assignment| assignment.value.release();
    assignments.clearRetainingCapacity();
    try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator, .tainted_ranges = &ranges }, .{ .longhand = .content }, text, &assignments));
}

fn rejectedSource(allocator: std.mem.Allocator) !void {
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://example.test/sheet.css" });
    defer source.unref();
    const text = "image(\"private.png\", red)";
    const ranges = [_]css.substitution.TaintRange{.{ .start = 6, .end = 17, .kind = .own }};
    for ([_]css.properties.Longhand{ .background_image, .content }) |longhand| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (assignments.items) |assignment| assignment.value.release();
            assignments.deinit(allocator);
        }
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator, .resource_source = source, .tainted_ranges = &ranges }, .{ .longhand = longhand }, text, &assignments));
        try testing.expectEqual(@as(u32, 1), source.refs.load(.monotonic));
    }
}

test "attr rejection: raw image resources release source holds on rejection and OOM" {
    try testing.checkAllAllocationFailures(testing.allocator, rejectedSource, .{});
}
