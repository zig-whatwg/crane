//! WebIDL dictionary: RTCRtpParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCRtpHeaderExtensionParameters = @import("RTCRtpHeaderExtensionParameters.zig").RTCRtpHeaderExtensionParameters;
const RTCRtcpParameters = @import("RTCRtcpParameters.zig").RTCRtcpParameters;
const RTCRtpCodecParameters = @import("RTCRtpCodecParameters.zig").RTCRtpCodecParameters;

pub const RTCRtpParameters = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    headerExtensions: []const RTCRtpHeaderExtensionParameters,
    rtcp: RTCRtcpParameters,
    codecs: []const RTCRtpCodecParameters,
};
