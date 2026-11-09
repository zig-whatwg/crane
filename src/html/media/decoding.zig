//! A media element's decoding, through the platform (protocol 6.10.5,
//! `media_decoding`): canPlayType's answer and one decoder per resource
//! fetch. The platform the build compiled in decides what it decodes and
//! whether its decoders are built in or link out to the OS (the user,
//! 2026-11-09, lane wptcfg D4); Crane's default platforms - darwin, linux and
//! testing - build in kit/media_decoding (WAV linear PCM). No decoder comes
//! from a host's BrowserConfig any more: a browser ships its decoders, and
//! every realm of a Browser reaches its Browser's platform state
//! (html.platform_state). Recipes step 7 (docs/platform-protocol-recipes.md):
//! HTMLMediaElement asks mediaCanPlayType, openMediaDecoder, pushMediaData,
//! mediaVideoSize and closeMediaDecoder, behind the capability.
//!
//! A realm with no Browser platform state (the standalone runtime's, a
//! test's), or a build without media_decoding, decodes nothing: canPlayType
//! answers "" and every resource is unsupported - HTML's dedicated media
//! source failure steps, never fabricated playable data.

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const platform_state = @import("../platform_state.zig");

const decodes = platform.capabilities.media_decoding != .unsupported;

/// HTML canPlayType's three answers.
pub const Support = platform.MediaSupport;

/// What a decoder learned of the resource. A resource with no video has a
/// 0x0 frame.
pub const Metadata = struct {
    duration: f64,
    width: u32 = 0,
    height: u32 = 0,
};

/// A decoder's answer to one push (the protocol's MediaResult with the
/// metadata it wrote).
pub const Result = union(enum) {
    need_more,
    unsupported,
    decode_error,
    metadata: Metadata,
    /// The decoder really has data at the current playback position.
    /// Container recognition or metadata alone never produces this. On the
    /// end_of_stream push: the whole resource is held, so HAVE_ENOUGH_DATA
    /// (HTML 4.8.11.7).
    current_data: Metadata,
};

/// The size, in pixels, of a video frame.
pub const VideoSize = struct { width: u32, height: u32 };

/// canPlayType(type) for `realm`'s Browser: its platform's answer, "" with
/// none.
pub fn canPlayType(realm: runtime.Context, mime: []const u8) Support {
    if (comptime !decodes) return .unsupported;
    const browser = platform_state.of(realm) orelse return .unsupported;
    return platform.mediaCanPlayType(browser, .from(mime));
}

/// One resource's decoder: the platform's, or none - then every push
/// answers `unsupported`. Bytes are borrowed for the push only. Exactly one
/// `deinit`.
pub const Decoder = struct {
    handle: ?*platform.MediaDecoder,

    /// A decoder for a resource of `realm`'s Browser whose Content-Type
    /// gave `mime` (an essence, or ""); the platform decides by the bytes.
    /// A platform that has none for it - or no platform - gives a decoder
    /// that answers `unsupported`.
    pub fn open(realm: runtime.Context, mime: []const u8) error{OutOfMemory}!Decoder {
        if (comptime !decodes) return .{ .handle = null };
        const browser = platform_state.of(realm) orelse return .{ .handle = null };
        const handle = platform.openMediaDecoder(browser, .from(mime)) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return .{ .handle = null },
        };
        return .{ .handle = handle };
    }

    pub fn push(self: Decoder, bytes: []const u8, end_of_stream: bool) Result {
        if (comptime !decodes) return .unsupported;
        const handle = self.handle orelse return .unsupported;
        var metadata: platform.MediaMetadata = .{};
        return switch (platform.pushMediaData(handle, .from(bytes), end_of_stream, &metadata)) {
            .need_more => .need_more,
            .unsupported => .unsupported,
            .decode_error => .decode_error,
            .metadata => .{ .metadata = .{ .duration = metadata.duration, .width = metadata.width, .height = metadata.height } },
            .current_data => .{ .current_data = .{ .duration = metadata.duration, .width = metadata.width, .height = metadata.height } },
        };
    }

    /// The size of the video frame at `seconds` on the media timeline - so
    /// the element follows a size change during playback (HTML 4.8.8 fires
    /// `resize` when the natural size changes): the frame the decoder really
    /// has there, never a guess from container metadata. Null when it does
    /// not know (no video, no frame there yet); the element keeps its last
    /// size.
    pub fn videoSizeAt(self: Decoder, seconds: f64) ?VideoSize {
        if (comptime !decodes) return null;
        const handle = self.handle orelse return null;
        var size: platform.VideoSize = .{ .width = 0, .height = 0 };
        if (!platform.mediaVideoSize(handle, seconds, &size)) return null;
        return .{ .width = size.width, .height = size.height };
    }

    pub fn deinit(self: *Decoder) void {
        if (comptime decodes) if (self.handle) |handle| platform.closeMediaDecoder(handle);
        self.* = undefined;
    }
};
