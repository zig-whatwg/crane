//! WebIDL dictionary: VideoFrameCallbackMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const VideoFrameCallbackMetadata = struct {
    presentationTime: anyopaque,
    expectedDisplayTime: anyopaque,
    width: u32,
    height: u32,
    mediaTime: f64,
    presentedFrames: u32,
    processingDuration: ?f64 = null,
    captureTime: ?anyopaque = null,
    receiveTime: ?anyopaque = null,
    rtpTimestamp: ?u32 = null,
};
