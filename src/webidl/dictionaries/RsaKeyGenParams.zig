//! WebIDL dictionary: RsaKeyGenParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const RsaKeyGenParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    modulusLength: u32,
    publicExponent: anyopaque,
};
