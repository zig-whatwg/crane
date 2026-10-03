//! WebIDL dictionary: PositionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PositionOptions = struct {
    enableHighAccuracy: ?bool = null,
    timeout: ?u32 = null,
    maximumAge: ?u32 = null,

    /// [Clamp] members: converted with that branch of ConvertToInt.
    pub const clamp_members = .{ "timeout", "maximumAge" };
};
