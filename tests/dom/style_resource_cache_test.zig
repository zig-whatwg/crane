//! Request equivalence is stricter than URL equality: a font's CORS request
//! cannot reuse a no-CORS image, or the referrer of another declaring sheet.
const std = @import("std");
const resources = @import("dom").style.engine.resource_loading;

test "resource interest recognizes escaped tokens without treating text as a URL" {
    try std.testing.expect(resources.mayHaveResources("background:u\\72l(image.png)"));
    try std.testing.expect(resources.mayHaveResources("@f\\6fnt-face { font-family:a; src:local(a) }"));
    try std.testing.expect(resources.mayHaveResources("content: url('image.png')"));
    try std.testing.expect(!resources.mayHaveResources("content: 'url(image.png)'"));
    try std.testing.expect(!resources.mayHaveResources("/* url(image.png) */ color:red"));
    try std.testing.expect(!resources.mayHaveResources("color:rgb(1 2 3); margin:2px"));
    try std.testing.expect(!resources.canCarryResource("data-image"));
    try std.testing.expect(resources.canCarryResource("style"));
    try std.testing.expect(resources.canCarryResource("marker-start"));
}

test "style resource keys distinguish request security and provenance" {
    const original: resources.RequestKey = .{
        .url = "https://assets.example/shared",
        .referrer = "https://styles.example/main.css",
        .referrer_policy = .origin,
    };
    var changed = original;
    try std.testing.expect(original.eql(changed));
    changed.destination = .font;
    try std.testing.expect(!original.eql(changed));
    changed = original;
    changed.mode = .cors;
    try std.testing.expect(!original.eql(changed));
    changed = original;
    changed.credentials = .same_origin;
    try std.testing.expect(!original.eql(changed));
    changed = original;
    changed.referrer_policy = .no_referrer;
    try std.testing.expect(!original.eql(changed));
    changed = original;
    changed.referrer = "https://styles.example/other.css";
    try std.testing.expect(!original.eql(changed));
    changed = original;
    changed.origin_clean = false;
    try std.testing.expect(!original.eql(changed));
}

test "style resource cache owns its keys and deduplicates pending requests" {
    var cache = resources.Cache.init(std.testing.allocator);
    defer cache.deinit();
    const url = try std.testing.allocator.dupe(u8, "https://assets.example/image.png");
    const referrer = try std.testing.allocator.dupe(u8, "https://styles.example/main.css");
    const first = try cache.getOrPut(.{ .url = url, .referrer = referrer });
    std.testing.allocator.free(url);
    std.testing.allocator.free(referrer);
    try std.testing.expect(!first.found_existing);
    try std.testing.expectEqual(.pending, first.entry.status);
    const second = try cache.getOrPut(.{
        .url = "https://assets.example/image.png",
        .referrer = "https://styles.example/main.css",
    });
    try std.testing.expect(second.found_existing);
    try std.testing.expectEqual(first.entry, second.entry);
    first.entry.status = .complete;
    const third = try cache.getOrPut(second.entry.key);
    try std.testing.expect(third.found_existing);
    try std.testing.expectEqual(.complete, third.entry.status);
    try std.testing.expectEqual(@as(usize, 1), cache.count());
}

test "style resource cache insertion is transactional on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(allocator: std.mem.Allocator) !void {
            var cache = resources.Cache.init(allocator);
            defer cache.deinit();
            _ = try cache.getOrPut(.{
                .url = "https://assets.example/image.png",
                .referrer = "https://styles.example/main.css",
            });
        }
    }.exercise, .{});
}

test "used image selection excludes nested candidates until a typed selector chooses one" {
    const css = @import("dom").style.css;
    const text = "url(\"first.png\"), image-set(url(\"one.png\") 1x, url(\"two.png\") 2x), url(\"last.png\")";
    var block = css.declarations.DeclarationBlock.init(std.testing.allocator);
    defer block.deinit();
    try std.testing.expect(try block.setProperty(.{ .allocator = std.testing.allocator }, "background", text, ""));
    // The background shorthand joins comma-separated layers. The
    // background-image longhand's missing list grammar is liaison Q6.
    const value = block.get(.background_image).?.value.value;
    const urls = value.resourceUrls();
    try std.testing.expectEqual(@as(usize, 4), urls.len);
    for (urls, [_]bool{ true, false, false, true }) |url, expected| {
        try std.testing.expectEqual(expected, @import("dom").style.engine.resource_loading.isSimpleImageOccurrence(value.sharedText().?.bytes, url.range));
    }
}

test "font cache keys keep request provenance separate and clean up every allocation failure" {
    const fonts = @import("dom").style.engine.resource_loading.font_loading;
    if (comptime !@hasDecl(fonts, "ResourceCache")) return error.MissingFontResourceCache;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(a: std.mem.Allocator) !void {
            var cache = fonts.ResourceCache.init(a);
            defer cache.deinit();
            try std.testing.expectEqual(@as(usize, 0), cache.count());
            const key = @import("dom").style.engine.resource_loading.RequestKey{
                .url = "https://font.example/a.woff2",
                .referrer = "https://sheet.example/main.css",
                .referrer_policy = .origin,
                .destination = .font,
                .mode = .cors,
                .credentials = .same_origin,
            };
            const first = try cache.getOrPut(key);
            try std.testing.expect(!first.found_existing);
            const repeated = try cache.getOrPut(key);
            try std.testing.expect(repeated.found_existing);
            try std.testing.expect(first.entry == repeated.entry);
            var changed = key;
            changed.referrer_policy = .no_referrer;
            const other = try cache.getOrPut(changed);
            try std.testing.expect(!other.found_existing);
            try std.testing.expect(other.entry != first.entry);
            try std.testing.expectEqual(@as(usize, 2), cache.count());
        }
    }.run, .{});
}
