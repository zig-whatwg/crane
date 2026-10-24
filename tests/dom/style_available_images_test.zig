const std = @import("std");
const dom = @import("dom");
const images = dom.style.engine.available_images;

fn image(allocator: std.mem.Allocator) !*images.Image {
    const pixels = try allocator.alloc(u8, 4);
    errdefer allocator.free(pixels);
    @memset(pixels, 255);
    return images.Image.create(allocator, .{ .width = 1, .height = 1, .pixels = pixels, .cors_same_origin = true });
}

test "available images own payloads without copying pixels" {
    var cache = images.Cache.init(std.testing.allocator);
    defer cache.deinit();
    const decoded = try image(std.testing.allocator);
    const address = decoded.pixels.ptr;
    try cache.put(.{ .url = "https://example.test/image.png" }, decoded);
    decoded.release();
    const reused = cache.get(.{ .url = "https://example.test/image.png" }).?;
    try std.testing.expectEqual(address, reused.pixels.ptr);
    const kept = reused.retain();
    defer kept.release();
    cache.clear();
    try std.testing.expectEqual(@as(u8, 255), kept.pixels[0]);
    try std.testing.expect(cache.get(.{ .url = "https://example.test/image.png" }) == null);
}

test "available-image keys distinguish CORS settings and opaque origin identity" {
    const first = try dom.origin_record.OriginRecord.create(std.testing.allocator, "null");
    defer first.release();
    const second = try dom.origin_record.OriginRecord.create(std.testing.allocator, "null");
    defer second.release();
    const anonymous: images.Key = .{ .url = "https://example.test/image.png", .cors = .anonymous, .origin = first };
    const other: images.Key = .{ .url = anonymous.url, .cors = .anonymous, .origin = second };
    try std.testing.expect(!anonymous.eql(other));
    try std.testing.expect(!anonymous.eql(.{ .url = anonymous.url, .cors = .use_credentials, .origin = first }));
    try std.testing.expect(!anonymous.eql(.{ .url = anonymous.url }));
    try std.testing.expect(images.Key.eql(.{ .url = anonymous.url, .origin = first }, .{ .url = anonymous.url, .origin = second }));
    var cache = images.Cache.init(std.testing.allocator);
    defer cache.deinit();
    const decoded = try image(std.testing.allocator);
    defer decoded.release();
    try cache.put(anonymous, decoded);
    try std.testing.expect(cache.get(anonymous) == decoded);
    try std.testing.expect(cache.get(other) == null);
}

test "available-image insertion rolls back every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn exercise(allocator: std.mem.Allocator) !void {
            var cache = images.Cache.init(allocator);
            defer cache.deinit();
            const decoded = try image(allocator);
            defer decoded.release();
            const origin = try dom.origin_record.OriginRecord.create(allocator, "https://example.test");
            defer origin.release();
            try cache.put(.{ .url = "https://example.test/image.png", .cors = .anonymous, .origin = origin }, decoded);
        }
    }.exercise, .{});
}
