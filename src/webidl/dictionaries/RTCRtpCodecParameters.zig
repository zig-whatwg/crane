//! WebIDL dictionary: RTCRtpCodecParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCRtpCodec = @import("RTCRtpCodec.zig").RTCRtpCodec;

pub const RTCRtpCodecParameters = struct {
    // Inherited from RTCRtpCodec
    base: RTCRtpCodec,

    payloadType: u8,
};
