//! WebIDL typedef: HTMLVideoElementOrVideoFrame
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const HTMLVideoElementOrVideoFrame = union(enum) {
    htmlvideo_element: *runtime.Instance,
    video_frame: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "htmlvideo_element", .kind = .{ .interface = "HTMLVideoElement" } },
        .{ .field = "video_frame", .kind = .{ .interface = "VideoFrame" } },
    };
};
