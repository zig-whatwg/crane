//! No decoder means unsupported, never fabricated playable data.
const std = @import("std");
const testing = std.testing;
const media = @import("platform").media_backend;

test "the default backend cannot play any type and owns no decoder resources" {
    for ([_][]const u8{ "", "video/webm", "audio/wav", "audio/ogg; codecs=opus", "video/mp4" }) |mime| {
        try testing.expectEqual(media.Support.unsupported, media.no_decoder.canPlayType(mime));
        var decoder = try media.no_decoder.open(testing.allocator, mime);
        defer decoder.deinit();
        try testing.expectEqual(media.Result.unsupported, decoder.push("RIFFnot decodable data", false));
        try testing.expectEqual(media.Result.unsupported, decoder.push("", true));
    }
}

test "a host decoder receives bytes, reports metadata and current data distinctly, and is destroyed once" {
    const Host = struct {
        bytes: usize = 0,
        destroyed: bool = false,
        fn push(ptr: ?*anyopaque, bytes: []const u8, end: bool) media.Result {
            const self: *@This() = @ptrCast(@alignCast(ptr.?));
            self.bytes += bytes.len;
            if (end) return .{ .current_data = .{ .duration = 4, .width = 640, .height = 480 } };
            return .{ .metadata = .{ .duration = 4, .width = 640, .height = 480 } };
        }
        fn destroy(ptr: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ptr.?));
            std.debug.assert(!self.destroyed);
            self.destroyed = true;
        }
    };
    var host: Host = .{};
    var decoder: media.Decoder = .{ .ptr = &host, .vtable = &.{ .push = Host.push, .deinit = Host.destroy } };
    const first = decoder.push("abc", false);
    try testing.expect(first == .metadata);
    try testing.expectEqual(@as(f64, 4), first.metadata.duration);
    const last = decoder.push("de", true);
    try testing.expect(last == .current_data);
    try testing.expectEqual(@as(u32, 640), last.current_data.width);
    try testing.expectEqual(@as(usize, 5), host.bytes);
    decoder.deinit();
    try testing.expect(host.destroyed);
}

test "C host adapter preserves result tags bytes and decoder ownership" {
    const adapter = @import("platform").media_adapter;
    const Host = struct {
        opens: u32 = 0,
        bytes: usize = 0,
        closes: u32 = 0,
        fn support(_: ?*anyopaque, _: [*]const u8, _: usize) callconv(.c) u8 {
            return 2;
        }
        fn open(raw: ?*anyopaque, _: [*]const u8, _: usize) callconv(.c) ?*anyopaque {
            const self: *@This() = @ptrCast(@alignCast(raw.?));
            self.opens += 1;
            return raw;
        }
        fn push(raw: ?*anyopaque, _: [*]const u8, length: usize, end: bool, metadata: *adapter.Metadata) callconv(.c) u8 {
            const self: *@This() = @ptrCast(@alignCast(raw.?));
            self.bytes += length;
            metadata.* = .{ .duration = 3.5, .width = 80, .height = 60 };
            return if (end) 4 else 3;
        }
        fn close(raw: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(raw.?));
            self.closes += 1;
        }
    };
    var host: Host = .{};
    var bridge = adapter.Adapter.init(&host, &.{ .can_play_type = Host.support, .open = Host.open, .push = Host.push, .close = Host.close });
    const backend = bridge.backend();
    try testing.expectEqual(media.Support.probably, backend.canPlayType("video/example"));
    var decoder = try backend.open(testing.allocator, "video/example");
    const metadata = decoder.push("ab", false);
    try testing.expect(metadata == .metadata);
    try testing.expectEqual(@as(f64, 3.5), metadata.metadata.duration);
    const data = decoder.push("cde", true);
    try testing.expect(data == .current_data);
    try testing.expectEqual(@as(u32, 80), data.current_data.width);
    decoder.deinit();
    try testing.expectEqual(@as(u32, 1), host.opens);
    try testing.expectEqual(@as(usize, 5), host.bytes);
    try testing.expectEqual(@as(u32, 1), host.closes);
}
