//! WebIDL dictionary: RsaHashedKeyAlgorithm
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RsaKeyAlgorithm = @import("RsaKeyAlgorithm.zig").RsaKeyAlgorithm;

pub const RsaHashedKeyAlgorithm = struct {
    // Inherited from RsaKeyAlgorithm
    base: RsaKeyAlgorithm,

    hash: anyopaque,
};
