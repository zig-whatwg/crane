//! WebIDL dictionary: Argon2Params
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const Argon2Params = struct {
    // Inherited from Algorithm
    base: Algorithm,

    nonce: anyopaque,
    parallelism: u32,
    memory: u32,
    passes: u32,
    version: ?u8 = null,
    secretValue: ?anyopaque = null,
    associatedData: ?anyopaque = null,
};
