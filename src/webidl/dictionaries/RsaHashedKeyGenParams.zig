//! WebIDL dictionary: RsaHashedKeyGenParams
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const RsaKeyGenParams = @import("RsaKeyGenParams.zig").RsaKeyGenParams;

pub const RsaHashedKeyGenParams = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from RsaKeyGenParams
    base: RsaKeyGenParams,

    hash: typedefs.HashAlgorithmIdentifier,
};
