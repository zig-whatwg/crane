//! WebIDL dictionary: RTCRtpCodec
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const RTCRtpCodec = struct {
    mimeType: runtime.DOMString,
    clockRate: u32,
    channels: ?u16 = null,
    sdpFmtpLine: ?runtime.DOMString = null,
};
