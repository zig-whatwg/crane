//! WebIDL dictionary: RTCEncodedFrameMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCEncodedFrameMetadata = struct {
    synchronizationSource: ?u32 = null,
    payloadType: ?u8 = null,
    contributingSources: ?anyopaque = null,
    rtpTimestamp: ?u32 = null,
    receiveTime: ?anyopaque = null,
    captureTime: ?anyopaque = null,
    senderCaptureTimeOffset: ?anyopaque = null,
    mimeType: ?runtime.DOMString = null,
};
