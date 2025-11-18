//! WebIDL dictionary: CShakeParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const CShakeParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    length: u32,
    functionName: ?anyopaque = null,
    customization: ?anyopaque = null,
};
