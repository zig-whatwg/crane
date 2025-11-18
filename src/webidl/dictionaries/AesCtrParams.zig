//! WebIDL dictionary: AesCtrParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const AesCtrParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    counter: anyopaque,
    length: u8,
};
