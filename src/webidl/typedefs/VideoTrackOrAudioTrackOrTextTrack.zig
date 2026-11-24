//! WebIDL typedef: VideoTrackOrAudioTrackOrTextTrack
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const VideoTrackOrAudioTrackOrTextTrack = union(enum) {
    video_track: *runtime.Instance,
    audio_track: *runtime.Instance,
    text_track: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "video_track", .kind = .{ .interface = "VideoTrack" } },
        .{ .field = "audio_track", .kind = .{ .interface = "AudioTrack" } },
        .{ .field = "text_track", .kind = .{ .interface = "TextTrack" } },
    };
};
