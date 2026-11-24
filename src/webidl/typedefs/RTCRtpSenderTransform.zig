//! WebIDL typedef: RTCRtpSenderTransform
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const RTCRtpSenderTransform = union(enum) {
    rtcrtp_sframe_encryptor: *runtime.Instance,
    rtcrtp_script_transform: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "rtcrtp_sframe_encryptor", .kind = .{ .interface = "RTCRtpSFrameEncryptor" } },
        .{ .field = "rtcrtp_script_transform", .kind = .{ .interface = "RTCRtpScriptTransform" } },
    };
};
