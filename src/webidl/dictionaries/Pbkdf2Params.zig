//! WebIDL dictionary: Pbkdf2Params
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const Pbkdf2Params = struct {
    // Inherited from Algorithm
    base: Algorithm,

    salt: typedefs.BufferSource,
    iterations: u32,
    hash: typedefs.HashAlgorithmIdentifier,
};
