//! WebIDL dictionary: RTCRtpTransceiverInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const RTCRtpEncodingParameters = @import("RTCRtpEncodingParameters.zig").RTCRtpEncodingParameters;

pub const RTCRtpTransceiverInit = struct {
    direction: ?enums.RTCRtpTransceiverDirection = null,
    streams: ?[]const *runtime.Instance = null,
    sendEncodings: ?[]const RTCRtpEncodingParameters = null,
};
