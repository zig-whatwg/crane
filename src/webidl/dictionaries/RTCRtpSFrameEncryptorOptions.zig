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

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "type", .{ .string = "per-frame" } },
    };
};
