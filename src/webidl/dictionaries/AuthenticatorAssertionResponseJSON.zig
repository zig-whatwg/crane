//! WebIDL dictionary: AuthenticatorAssertionResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AuthenticatorAssertionResponseJSON = struct {
    clientDataJSON: typedefs.Base64URLString,
    authenticatorData: typedefs.Base64URLString,
    signature: typedefs.Base64URLString,
    userHandle: ?typedefs.Base64URLString = null,
};
