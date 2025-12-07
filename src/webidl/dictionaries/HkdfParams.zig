//! WebIDL dictionary: HkdfParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const Algorithm = @import("Algorithm.zig").Algorithm;

pub const HkdfParams = struct {
    // Inherited from Algorithm
    base: Algorithm,

    hash: typedefs.HashAlgorithmIdentifier,
    salt: typedefs.BufferSource,
    info: typedefs.BufferSource,
};
