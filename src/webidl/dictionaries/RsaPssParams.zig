//! WebIDL dictionary: RsaPssParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const RsaPssParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    saltLength: u32,
};
