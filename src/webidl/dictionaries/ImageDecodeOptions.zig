//! WebIDL dictionary: ImageDecodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ImageDecodeOptions = struct {
    frameIndex: ?u32 = null,
    completeFramesOnly: ?bool = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"frameIndex"};
};
