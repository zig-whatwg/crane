//! WebIDL typedef: RTCEncodedVideoFrameOrRTCEncodedAudioFrame
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const RTCEncodedVideoFrameOrRTCEncodedAudioFrame = union(enum) {
    rtcencoded_video_frame: *runtime.Instance,
    rtcencoded_audio_frame: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "rtcencoded_video_frame", .kind = .{ .interface = "RTCEncodedVideoFrame" } },
        .{ .field = "rtcencoded_audio_frame", .kind = .{ .interface = "RTCEncodedAudioFrame" } },
    };
};
