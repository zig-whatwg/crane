//! WebIDL dictionary: PublicKeyCredentialCreationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PublicKeyCredentialCreationOptions = struct {
    rp: anyopaque,
    user: anyopaque,
    challenge: anyopaque,
    pubKeyCredParams: anyopaque,
    timeout: ?u32 = null,
    excludeCredentials: ?anyopaque = null,
    authenticatorSelection: ?anyopaque = null,
    hints: ?anyopaque = null,
    attestation: ?runtime.DOMString = null,
    attestationFormats: ?anyopaque = null,
    extensions: ?anyopaque = null,
};
