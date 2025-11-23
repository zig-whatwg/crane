//! WebIDL dictionary: PublicKeyCredentialCreationOptionsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PublicKeyCredentialCreationOptionsJSON = struct {
    rp: *const anyopaque,
    user: *const anyopaque,
    challenge: *const anyopaque,
    pubKeyCredParams: *const anyopaque,
    timeout: ?u32 = null,
    excludeCredentials: ?*const anyopaque = null,
    authenticatorSelection: ?*const anyopaque = null,
    hints: ?*const anyopaque = null,
    attestation: ?runtime.DOMString = null,
    attestationFormats: ?*const anyopaque = null,
    extensions: ?*const anyopaque = null,
};
