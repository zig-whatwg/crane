//! WebIDL dictionary: AesCbcParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const AesCbcParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    iv: typedefs.BufferSource,
};
