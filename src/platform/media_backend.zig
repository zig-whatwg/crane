//! Host-supplied decoding. Fetch, CORS, CSP, events and HTML state stay in Crane.
//! Like LayoutBackend, this is an instance/vtable pair; it has no global override.
const std = @import("std");

pub const Support = enum { unsupported, maybe, probably };
pub const Metadata = struct {
    duration: f64,
    width: u32 = 0,
    height: u32 = 0,
};
pub const Result = union(enum) {
    need_more,
    unsupported,
    decode_error,
    metadata: Metadata,
    /// The decoder really has data at the current playback position. Container
    /// recognition or metadata alone must never produce this result.
    current_data: Metadata,
};

/// One resource's decoder. Bytes are borrowed for push only; the host owns any
/// retained copy. A successful open transfers exactly one deinit to the caller.
pub const Decoder = struct {
    ptr: ?*anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        push: *const fn (?*anyopaque, []const u8, bool) Result,
        deinit: *const fn (?*anyopaque) void,
    };
    pub fn push(self: Decoder, bytes: []const u8, end_of_stream: bool) Result {
        return self.vtable.push(self.ptr, bytes, end_of_stream);
    }
    pub fn deinit(self: *Decoder) void {
        self.vtable.deinit(self.ptr);
        self.* = undefined;
    }
};

pub const MediaBackend = struct {
    ptr: ?*anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        /// MIME, including codecs, is borrowed for this call.
        can_play_type: *const fn (?*anyopaque, []const u8) Support,
        open: *const fn (?*anyopaque, std.mem.Allocator, []const u8) anyerror!Decoder,
    };
    pub fn canPlayType(self: MediaBackend, mime: []const u8) Support {
        return self.vtable.can_play_type(self.ptr, mime);
    }
    pub fn open(self: MediaBackend, allocator: std.mem.Allocator, mime: []const u8) !Decoder {
        return self.vtable.open(self.ptr, allocator, mime);
    }
};

/// Deliberately no decoding: a successful fetch is not proof of playable data.
pub const no_decoder: MediaBackend = .{ .ptr = null, .vtable = &.{ .can_play_type = cannotPlay, .open = openUnsupported } };
fn cannotPlay(_: ?*anyopaque, _: []const u8) Support {
    return .unsupported;
}
fn openUnsupported(_: ?*anyopaque, _: std.mem.Allocator, _: []const u8) !Decoder {
    return .{ .ptr = null, .vtable = &.{ .push = unsupported, .deinit = discard } };
}
fn unsupported(_: ?*anyopaque, _: []const u8, _: bool) Result {
    return .unsupported;
}
fn discard(_: ?*anyopaque) void {}
