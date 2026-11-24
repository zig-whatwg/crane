//! WebIDL typedef: MediaStreamTrackOrHandle
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const MediaStreamTrackOrHandle = union(enum) {
    media_stream_track: *runtime.Instance,
    media_stream_track_handle: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "media_stream_track", .kind = .{ .interface = "MediaStreamTrack" } },
        .{ .field = "media_stream_track_handle", .kind = .{ .interface = "MediaStreamTrackHandle" } },
    };
};
