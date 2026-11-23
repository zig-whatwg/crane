//! WebIDL dictionary: RTCRtpCodec
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCRtpCodec = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    mimeType: runtime.DOMString,
    clockRate: u32,
    channels: ?u16 = null,
    sdpFmtpLine: ?runtime.DOMString = null,
};
