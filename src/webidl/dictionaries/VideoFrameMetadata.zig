//! WebIDL dictionary: VideoFrameMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Segment = @import("Segment.zig").Segment;
const BackgroundBlur = @import("BackgroundBlur.zig").BackgroundBlur;

pub const VideoFrameMetadata = struct {
    segments: ?[]const Segment = null,
    backgroundBlur: ?BackgroundBlur = null,
    backgroundSegmentationMask: ?*runtime.Instance = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "backgroundSegmentationMask", "ImageBitmap" },
    };
};
