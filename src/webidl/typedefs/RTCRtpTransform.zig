//! WebIDL typedef: RTCRtpTransform
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const RTCRtpTransform = union(enum) {
    sframe_transform: *runtime.Instance,
    rtcrtp_script_transform: *runtime.Instance,
};
