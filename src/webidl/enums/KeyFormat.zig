//! WebIDL enum: KeyFormat
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const KeyFormat = enum {
    _raw_public_,
    _raw_private_,
    _raw_seed_,
    _raw_secret_,
    _raw_,
    _spki_,
    _pkcs8_,
    _jwk_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "raw-public", "raw-private", "raw-seed", "raw-secret", "raw", "spki", "pkcs8", "jwk" };
};
