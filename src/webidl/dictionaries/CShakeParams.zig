//! WebIDL dictionary: CShakeParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const CShakeParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    length: u32,
    functionName: ?typedefs.BufferSource = null,
    customization: ?typedefs.BufferSource = null,
};
