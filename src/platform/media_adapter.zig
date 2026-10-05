//! Realm-free C host adapter for media decoding. Fetch and HTML stay in Crane;
//! BrowserScope wiring is the separately queued host-backend follow-up (Q4).
const std = @import("std");
const media = @import("media_backend.zig");

pub const Metadata = extern struct {
    duration: f64,
    width: u32,
    height: u32,
};

/// All byte spans are borrowed for the call. The host owns its decoder handle
/// from open until close; null from open means unsupported. No Zig allocator,
/// slice, error union, realm or engine handle crosses this C boundary.
pub const VTable = extern struct {
    /// 0 unsupported, 1 maybe, 2 probably. Unknown values mean unsupported.
    can_play_type: *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) u8,
    open: *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) ?*anyopaque,
    /// 0 need_more, 1 unsupported, 2 decode_error, 3 metadata, 4 current_data.
    /// Only tags 3 and 4 initialize the output metadata.
    push: *const fn (?*anyopaque, [*]const u8, usize, bool, *Metadata) callconv(.c) u8,
    close: *const fn (?*anyopaque) callconv(.c) void,
};

/// The embedder keeps this adapter alive while using backend(). A decoder
/// copies the host vtable and handle; it owns only its small native wrapper.
pub const Adapter = struct {
    context: ?*anyopaque,
    host: *const VTable,
    pub fn init(context: ?*anyopaque, host: *const VTable) Adapter {
        return .{ .context = context, .host = host };
    }
    pub fn backend(self: *Adapter) media.MediaBackend {
        return .{ .ptr = self, .vtable = &.{ .can_play_type = canPlay, .open = open } };
    }
    fn canPlay(raw: ?*anyopaque, mime: []const u8) media.Support {
        const self: *Adapter = @ptrCast(@alignCast(raw.?));
        return switch (self.host.can_play_type(self.context, mime.ptr, mime.len)) {
            1 => .maybe,
            2 => .probably,
            else => .unsupported,
        };
    }
    fn open(raw: ?*anyopaque, allocator: std.mem.Allocator, mime: []const u8) !media.Decoder {
        const self: *Adapter = @ptrCast(@alignCast(raw.?));
        // Allocate first: no failure after open can strand the host's handle.
        const decoder = try allocator.create(Decoder);
        errdefer allocator.destroy(decoder);
        const handle = self.host.open(self.context, mime.ptr, mime.len) orelse return error.NotSupported;
        decoder.* = .{ .allocator = allocator, .handle = handle, .host = self.host };
        return .{ .ptr = decoder, .vtable = &.{ .push = Decoder.push, .deinit = Decoder.deinit } };
    }
};
const Decoder = struct {
    allocator: std.mem.Allocator,
    handle: *anyopaque,
    host: *const VTable,
    fn push(raw: ?*anyopaque, bytes: []const u8, end: bool) media.Result {
        const self: *Decoder = @ptrCast(@alignCast(raw.?));
        var metadata: Metadata = undefined;
        const tag = self.host.push(self.handle, bytes.ptr, bytes.len, end, &metadata);
        return switch (tag) {
            0 => .need_more,
            1 => .unsupported,
            3 => .{ .metadata = .{ .duration = metadata.duration, .width = metadata.width, .height = metadata.height } },
            4 => .{ .current_data = .{ .duration = metadata.duration, .width = metadata.width, .height = metadata.height } },
            else => .decode_error,
        };
    }
    fn deinit(raw: ?*anyopaque) void {
        const self: *Decoder = @ptrCast(@alignCast(raw.?));
        self.host.close(self.handle);
        self.allocator.destroy(self);
    }
};
