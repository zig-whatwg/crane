//! WebIDL typedef: RTCRtpSenderTransform
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCRtpSenderTransform = union(enum) {
    rtcrtp_sframe_encryptor: *runtime.Instance,
    rtcrtp_script_transform: *runtime.Instance,
};
