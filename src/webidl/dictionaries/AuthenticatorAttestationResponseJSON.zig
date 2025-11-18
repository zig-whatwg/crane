//! WebIDL dictionary: AuthenticatorAttestationResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticatorAttestationResponseJSON = struct {
    clientDataJSON: anyopaque,
    authenticatorData: anyopaque,
    transports: anyopaque,
    publicKey: ?anyopaque = null,
    publicKeyAlgorithm: anyopaque,
    attestationObject: anyopaque,
};
