//! WebIDL dictionary: RTCRtpCapabilities
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCRtpCodec = @import("RTCRtpCodec.zig").RTCRtpCodec;
const RTCRtpHeaderExtensionCapability = @import("RTCRtpHeaderExtensionCapability.zig").RTCRtpHeaderExtensionCapability;

pub const RTCRtpCapabilities = struct {
    codecs: []const RTCRtpCodec,
    headerExtensions: []const RTCRtpHeaderExtensionCapability,
};
