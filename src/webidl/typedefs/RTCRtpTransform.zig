//! WebIDL typedef: RTCRtpTransform
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCRtpTransform = union(enum) {
    sframe_transform: *runtime.Instance,
    rtcrtp_script_transform: *runtime.Instance,
};
