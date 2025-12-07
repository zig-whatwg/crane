//! WebIDL dictionary: RsaOaepParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const RsaOaepParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    label: ?typedefs.BufferSource = null,
};
