//! WebIDL dictionary: AuthenticatorAttestationResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticatorAttestationResponseJSON = struct {
    clientDataJSON: *const anyopaque,
    authenticatorData: *const anyopaque,
    transports: *const anyopaque,
    publicKey: ?*const anyopaque = null,
    publicKeyAlgorithm: *const anyopaque,
    attestationObject: *const anyopaque,
};
