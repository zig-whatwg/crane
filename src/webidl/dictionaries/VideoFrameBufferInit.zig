//! WebIDL dictionary: VideoFrameBufferInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VideoFrameBufferInit = struct {
    format: anyopaque,
    codedWidth: u32,
    codedHeight: u32,
    timestamp: i64,
    duration: ?u64 = null,
    layout: ?anyopaque = null,
    visibleRect: ?anyopaque = null,
    rotation: ?f64 = null,
    flip: ?bool = null,
    displayWidth: ?u32 = null,
    displayHeight: ?u32 = null,
    colorSpace: ?anyopaque = null,
    transfer: ?anyopaque = null,
    metadata: ?anyopaque = null,
};
