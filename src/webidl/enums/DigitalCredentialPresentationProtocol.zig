//! WebIDL enum: DigitalCredentialPresentationProtocol
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const DigitalCredentialPresentationProtocol = enum {
    _openid4vp_v1_unsigned_,
    _openid4vp_v1_signed_,
    _openid4vp_v1_multisigned_,
    _org_iso_mdoc_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "openid4vp-v1-unsigned", "openid4vp-v1-signed", "openid4vp-v1-multisigned", "org-iso-mdoc" };
};
