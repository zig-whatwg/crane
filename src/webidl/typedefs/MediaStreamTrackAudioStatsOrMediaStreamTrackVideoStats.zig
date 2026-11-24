//! WebIDL typedef: MediaStreamTrackAudioStatsOrMediaStreamTrackVideoStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const MediaStreamTrackAudioStatsOrMediaStreamTrackVideoStats = union(enum) {
    media_stream_track_audio_stats: *runtime.Instance,
    media_stream_track_video_stats: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "media_stream_track_audio_stats", .kind = .{ .interface = "MediaStreamTrackAudioStats" } },
        .{ .field = "media_stream_track_video_stats", .kind = .{ .interface = "MediaStreamTrackVideoStats" } },
    };
};
