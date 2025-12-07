//! WebIDL dictionary: RTCEncodedFrameMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const RTCEncodedFrameMetadata = struct {
    synchronizationSource: ?u32 = null,
    payloadType: ?u8 = null,
    contributingSources: ?[]const u32 = null,
    rtpTimestamp: ?u32 = null,
    receiveTime: ?typedefs.DOMHighResTimeStamp = null,
    captureTime: ?typedefs.DOMHighResTimeStamp = null,
    senderCaptureTimeOffset: ?typedefs.DOMHighResTimeStamp = null,
    mimeType: ?runtime.DOMString = null,
};
