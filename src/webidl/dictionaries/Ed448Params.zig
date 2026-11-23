//! WebIDL dictionary: Ed448Params
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const Ed448Params = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from Algorithm
    base: Algorithm,

    context: ?typedefs.BufferSource = null,
};
