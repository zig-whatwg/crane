//! WebIDL enum: SFrameCipherSuite
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const SFrameCipherSuite = enum {
    _AES_128_CTR_HMAC_SHA256_80_,
    _AES_128_CTR_HMAC_SHA256_64_,
    _AES_128_CTR_HMAC_SHA256_32_,
    _AES_128_GCM_SHA256_128_,
    _AES_256_GCM_SHA512_128_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "AES_128_CTR_HMAC_SHA256_80", "AES_128_CTR_HMAC_SHA256_64", "AES_128_CTR_HMAC_SHA256_32", "AES_128_GCM_SHA256_128", "AES_256_GCM_SHA512_128" };
};
