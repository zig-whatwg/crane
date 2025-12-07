//! WebIDL dictionary: RsaKeyGenParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const RsaKeyGenParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    modulusLength: u32,
    publicExponent: typedefs.BigInteger,
};
