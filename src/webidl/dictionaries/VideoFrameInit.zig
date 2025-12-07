//! WebIDL dictionary: VideoFrameInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const VideoFrameMetadata = @import("VideoFrameMetadata.zig").VideoFrameMetadata;
const DOMRectInit = @import("DOMRectInit.zig").DOMRectInit;

pub const VideoFrameInit = struct {
    duration: ?u64 = null,
    timestamp: ?i64 = null,
    alpha: ?enums.AlphaOption = null,
    visibleRect: ?DOMRectInit = null,
    rotation: ?f64 = null,
    flip: ?bool = null,
    displayWidth: ?u32 = null,
    displayHeight: ?u32 = null,
    metadata: ?VideoFrameMetadata = null,
};
