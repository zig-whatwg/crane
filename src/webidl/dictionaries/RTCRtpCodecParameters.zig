//! WebIDL dictionary: RTCRtpCodecParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCRtpCodec = @import("RTCRtpCodec.zig").RTCRtpCodec;

pub const RTCRtpCodecParameters = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from RTCRtpCodec
    base: RTCRtpCodec,

    payloadType: u8,
};
