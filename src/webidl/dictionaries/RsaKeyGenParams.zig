//! WebIDL dictionary: RsaKeyGenParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const RsaKeyGenParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    modulusLength: u32,
    publicExponent: typedefs.BigInteger,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"modulusLength"};
};
