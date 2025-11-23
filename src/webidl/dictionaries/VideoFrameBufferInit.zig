//! WebIDL dictionary: VideoFrameBufferInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VideoFrameBufferInit = struct {
    format: *const anyopaque,
    codedWidth: u32,
    codedHeight: u32,
    timestamp: i64,
    duration: ?u64 = null,
    layout: ?*const anyopaque = null,
    visibleRect: ?*const anyopaque = null,
    rotation: ?f64 = null,
    flip: ?bool = null,
    displayWidth: ?u32 = null,
    displayHeight: ?u32 = null,
    colorSpace: ?*const anyopaque = null,
    transfer: ?*const anyopaque = null,
    metadata: ?*const anyopaque = null,
};
