//! WebIDL dictionary: TurboShakeParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const TurboShakeParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    outputLength: u32,
    domainSeparation: ?u8 = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{ "outputLength", "domainSeparation" };
};
