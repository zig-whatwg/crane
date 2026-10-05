//! WebIDL enum: KeyUsage
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const KeyUsage = enum {
    _encrypt_,
    _decrypt_,
    _sign_,
    _verify_,
    _deriveKey_,
    _deriveBits_,
    _wrapKey_,
    _unwrapKey_,
    _encapsulateKey_,
    _encapsulateBits_,
    _decapsulateKey_,
    _decapsulateBits_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "encrypt", "decrypt", "sign", "verify", "deriveKey", "deriveBits", "wrapKey", "unwrapKey", "encapsulateKey", "encapsulateBits", "decapsulateKey", "decapsulateBits" };
};
