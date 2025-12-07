//! WebIDL dictionary: RTCRtpSendParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const RTCRtpEncodingParameters = @import("RTCRtpEncodingParameters.zig").RTCRtpEncodingParameters;
const RTCRtpParameters = @import("RTCRtpParameters.zig").RTCRtpParameters;

pub const RTCRtpSendParameters = struct {
    // Inherited from RTCRtpParameters
    base: RTCRtpParameters,

    transactionId: runtime.DOMString,
    encodings: []const RTCRtpEncodingParameters,
    degradationPreference: ?enums.RTCDegradationPreference = null,
};
