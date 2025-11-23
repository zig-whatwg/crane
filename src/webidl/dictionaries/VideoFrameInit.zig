//! WebIDL dictionary: VideoFrameInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VideoFrameInit = struct {
    duration: ?u64 = null,
    timestamp: ?i64 = null,
    alpha: ?*const anyopaque = null,
    visibleRect: ?*const anyopaque = null,
    rotation: ?f64 = null,
    flip: ?bool = null,
    displayWidth: ?u32 = null,
    displayHeight: ?u32 = null,
    metadata: ?*const anyopaque = null,
};
