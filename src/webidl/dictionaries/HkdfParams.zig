//! WebIDL dictionary: HkdfParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const HkdfParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    hash: *const anyopaque,
    salt: *const anyopaque,
    info: *const anyopaque,
};
