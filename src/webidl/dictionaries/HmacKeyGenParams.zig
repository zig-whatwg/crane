//! WebIDL dictionary: HmacKeyGenParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const HmacKeyGenParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    hash: typedefs.HashAlgorithmIdentifier,
    length: ?u32 = null,
};
