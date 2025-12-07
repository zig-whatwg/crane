//! WebIDL dictionary: AuthenticatorAttestationResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const AuthenticatorAttestationResponseJSON = struct {
    clientDataJSON: typedefs.Base64URLString,
    authenticatorData: typedefs.Base64URLString,
    transports: []const runtime.DOMString,
    publicKey: ?typedefs.Base64URLString = null,
    publicKeyAlgorithm: typedefs.COSEAlgorithmIdentifier,
    attestationObject: typedefs.Base64URLString,
};
