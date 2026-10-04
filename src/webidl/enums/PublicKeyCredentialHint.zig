//! WebIDL enum: PublicKeyCredentialHint
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const PublicKeyCredentialHint = enum {
    _security_key_,
    _client_device_,
    _hybrid_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "security-key", "client-device", "hybrid" };
};
