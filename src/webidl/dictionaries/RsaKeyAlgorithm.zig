//! WebIDL dictionary: RsaKeyAlgorithm
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const KeyAlgorithm = @import("KeyAlgorithm.zig").KeyAlgorithm;

pub const RsaKeyAlgorithm = struct {
    // Inherited from KeyAlgorithm
    base: KeyAlgorithm,

    modulusLength: u32,
    publicExponent: typedefs.BigInteger,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"modulusLength"};
};
