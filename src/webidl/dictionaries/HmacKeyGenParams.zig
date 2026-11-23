//! WebIDL dictionary: HmacKeyGenParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const HmacKeyGenParams = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from Algorithm
    base: Algorithm,

    hash: typedefs.HashAlgorithmIdentifier,
    length: ?u32 = null,

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"length"};
};
