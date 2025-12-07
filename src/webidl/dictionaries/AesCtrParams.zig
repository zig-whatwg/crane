//! WebIDL dictionary: AesCtrParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const AesCtrParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    counter: typedefs.BufferSource,
    length: u8,
};
