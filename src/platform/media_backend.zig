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
    /// On the end_of_stream push: the whole resource is held, so HAVE_ENOUGH_DATA (HTML 4.8.11.7).
    current_data: Metadata,
};

/// The size, in pixels, of a video frame.
pub const VideoSize = struct { width: u32, height: u32 };

/// One resource's decoder. Bytes are borrowed for push only; the host owns any
/// retained copy. A successful open transfers exactly one deinit to the caller.
pub const Decoder = struct {
    ptr: ?*anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        push: *const fn (?*anyopaque, []const u8, bool) Result,
        deinit: *const fn (?*anyopaque) void,
        /// The size of the video frame at a playback position, in seconds on
        /// the media timeline - so the element can follow a size change
        /// during playback (HTML 4.8.8 fires `resize` when the natural
        /// size changes). Any host, iOS included: the size of the frame the
        /// decoder really has at that position, never a guess from container
        /// metadata; null when it does not know (no video, no frame there
        /// yet), and the element keeps its last size. Optional: a host that
        /// leaves it out answers null everywhere.
        video_size_at: ?*const fn (?*anyopaque, f64) ?VideoSize = null,
    };
    pub fn push(self: Decoder, bytes: []const u8, end_of_stream: bool) Result {
        return self.vtable.push(self.ptr, bytes, end_of_stream);
    }
    /// See VTable.video_size_at.
    pub fn videoSizeAt(self: Decoder, seconds: f64) ?VideoSize {
        const answer = self.vtable.video_size_at orelse return null;
        return answer(self.ptr, seconds);
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
