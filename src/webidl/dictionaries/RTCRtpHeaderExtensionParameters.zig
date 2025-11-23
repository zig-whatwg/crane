//! WebIDL dictionary: RTCRtpHeaderExtensionParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCRtpHeaderExtensionParameters = struct {
    uri: runtime.DOMString,
    id: u16,
    encrypted: ?bool = null,
};
