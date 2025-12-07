//! WebIDL dictionary: RTCRtpEncodingParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const RTCRtpCodec = @import("RTCRtpCodec.zig").RTCRtpCodec;
const RTCRtpCodingParameters = @import("RTCRtpCodingParameters.zig").RTCRtpCodingParameters;

pub const RTCRtpEncodingParameters = struct {
    // Inherited from RTCRtpCodingParameters
    base: RTCRtpCodingParameters,

    active: ?bool = null,
    codec: ?RTCRtpCodec = null,
    maxBitrate: ?u32 = null,
    maxFramerate: ?f64 = null,
    scaleResolutionDownBy: ?f64 = null,
    priority: ?enums.RTCPriorityType = null,
    networkPriority: ?enums.RTCPriorityType = null,
    scalabilityMode: ?runtime.DOMString = null,
};
