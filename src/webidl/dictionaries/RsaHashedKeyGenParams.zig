//! WebIDL dictionary: RsaHashedKeyGenParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RsaKeyGenParams = @import("RsaKeyGenParams.zig").RsaKeyGenParams;

pub const RsaHashedKeyGenParams = struct {
    // Inherited from RsaKeyGenParams
    base: RsaKeyGenParams,

    hash: anyopaque,
};
