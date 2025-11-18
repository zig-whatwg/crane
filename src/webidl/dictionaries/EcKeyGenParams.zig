//! WebIDL dictionary: EcKeyGenParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const EcKeyGenParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    namedCurve: anyopaque,
};
