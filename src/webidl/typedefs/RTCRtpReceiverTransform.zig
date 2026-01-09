//! WebIDL typedef: RTCRtpReceiverTransform
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCRtpReceiverTransform = union(enum) {
    sframe_receiver_transform: *runtime.Instance,
    rtcrtp_script_transform: *runtime.Instance,
};
