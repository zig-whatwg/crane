//! WebIDL dictionary: ContextParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const ContextParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    context: ?anyopaque = null,
};
