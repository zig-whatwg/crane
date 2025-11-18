//! WebIDL dictionary: Pbkdf2Params
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const Pbkdf2Params = struct {
    // Inherited from Algorithm
    base: Algorithm,

    salt: anyopaque,
    iterations: u32,
    hash: anyopaque,
};
