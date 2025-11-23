//! WebIDL dictionary: RTCEncodedFrameMetadata
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCEncodedFrameMetadata = struct {
    synchronizationSource: ?u32 = null,
    payloadType: ?u8 = null,
    contributingSources: ?*const anyopaque = null,
    rtpTimestamp: ?u32 = null,
    receiveTime: ?*const anyopaque = null,
    captureTime: ?*const anyopaque = null,
    senderCaptureTimeOffset: ?*const anyopaque = null,
    mimeType: ?runtime.DOMString = null,
};
