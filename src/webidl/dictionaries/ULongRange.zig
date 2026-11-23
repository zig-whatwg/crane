//! WebIDL dictionary: ULongRange
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ULongRange = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    max: ?u32 = null,
    min: ?u32 = null,

    /// [Clamp] members: converted with that branch of ConvertToInt.
    pub const clamp_members = .{ "max", "min" };
};
