//! WebIDL dictionary: Ed448Params
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const Ed448Params = struct {
    // Inherited from Algorithm
    base: Algorithm,

    context: ?typedefs.BufferSource = null,
};
