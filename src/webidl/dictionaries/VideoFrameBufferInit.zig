//! WebIDL dictionary: VideoFrameBufferInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const PlaneLayout = @import("PlaneLayout.zig").PlaneLayout;
const VideoFrameMetadata = @import("VideoFrameMetadata.zig").VideoFrameMetadata;
const VideoColorSpaceInit = @import("VideoColorSpaceInit.zig").VideoColorSpaceInit;
const DOMRectInit = @import("DOMRectInit.zig").DOMRectInit;

pub const VideoFrameBufferInit = struct {
    format: enums.VideoPixelFormat,
    codedWidth: u32,
    codedHeight: u32,
    timestamp: i64,
    duration: ?u64 = null,
    layout: ?[]const PlaneLayout = null,
    visibleRect: ?DOMRectInit = null,
    rotation: ?f64 = null,
    flip: ?bool = null,
    displayWidth: ?u32 = null,
    displayHeight: ?u32 = null,
    colorSpace: ?VideoColorSpaceInit = null,
    transfer: ?[]const *const anyopaque = null,
    metadata: ?VideoFrameMetadata = null,
};
