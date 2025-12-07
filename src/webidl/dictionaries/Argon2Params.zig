//! WebIDL dictionary: Argon2Params
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const Argon2Params = struct {
    // Inherited from Algorithm
    base: Algorithm,

    nonce: typedefs.BufferSource,
    parallelism: u32,
    memory: u32,
    passes: u32,
    version: ?u8 = null,
    secretValue: ?typedefs.BufferSource = null,
    associatedData: ?typedefs.BufferSource = null,
};
