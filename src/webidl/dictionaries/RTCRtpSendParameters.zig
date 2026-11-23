//! WebIDL dictionary: RTCRtpSendParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const RTCRtpEncodingParameters = @import("RTCRtpEncodingParameters.zig").RTCRtpEncodingParameters;
const RTCRtpParameters = @import("RTCRtpParameters.zig").RTCRtpParameters;

pub const RTCRtpSendParameters = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from RTCRtpParameters
    base: RTCRtpParameters,

    transactionId: runtime.DOMString,
    encodings: []const RTCRtpEncodingParameters,
    degradationPreference: ?enums.RTCDegradationPreference = null,
};
