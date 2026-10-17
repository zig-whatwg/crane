//! WebIDL dictionary: RTCRtpSFrameEncryptorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const SFrameTransformOptions = @import("SFrameTransformOptions.zig").SFrameTransformOptions;

pub const RTCRtpSFrameEncryptorOptions = struct {
    // Inherited from SFrameTransformOptions
    base: SFrameTransformOptions,

    type: ?enums.SFrameType = null,
};
