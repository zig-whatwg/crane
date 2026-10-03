//! WebIDL dictionary: ConstrainULongRange
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ULongRange = @import("ULongRange.zig").ULongRange;

pub const ConstrainULongRange = struct {
    // Inherited from ULongRange
    base: ULongRange,

    exact: ?u32 = null,
    ideal: ?u32 = null,

    /// [Clamp] members: converted with that branch of ConvertToInt.
    pub const clamp_members = .{ "exact", "ideal" };
};
