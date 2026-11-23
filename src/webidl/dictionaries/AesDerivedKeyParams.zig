//! WebIDL dictionary: AesDerivedKeyParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const AesDerivedKeyParams = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from Algorithm
    base: Algorithm,

    length: u16,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"length"};
};
