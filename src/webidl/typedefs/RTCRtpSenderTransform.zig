//! WebIDL typedef: RTCRtpSenderTransform
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCRtpSenderTransform = union(enum) {
    sframe_sender_transform: *runtime.Instance,
    rtcrtp_script_transform: *runtime.Instance,
};
