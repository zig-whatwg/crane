//! WebIDL dictionary: RsaHashedKeyGenParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const RsaKeyGenParams = @import("RsaKeyGenParams.zig").RsaKeyGenParams;

pub const RsaHashedKeyGenParams = struct {
    // Inherited from RsaKeyGenParams
    base: RsaKeyGenParams,

    hash: typedefs.HashAlgorithmIdentifier,
};
