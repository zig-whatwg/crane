//! WebIDL dictionary: VideoFrameCallbackMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const VideoFrameCallbackMetadata = struct {
    presentationTime: typedefs.DOMHighResTimeStamp,
    expectedDisplayTime: typedefs.DOMHighResTimeStamp,
    width: u32,
    height: u32,
    mediaTime: f64,
    presentedFrames: u32,
    processingDuration: ?f64 = null,
    captureTime: ?typedefs.DOMHighResTimeStamp = null,
    receiveTime: ?typedefs.DOMHighResTimeStamp = null,
    rtpTimestamp: ?u32 = null,
};
