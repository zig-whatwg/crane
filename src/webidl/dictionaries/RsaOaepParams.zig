//! WebIDL dictionary: RsaOaepParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const RsaOaepParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    label: ?anyopaque = null,
};
