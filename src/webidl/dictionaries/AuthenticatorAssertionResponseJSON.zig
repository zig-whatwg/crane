//! WebIDL dictionary: AuthenticatorAssertionResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AuthenticatorAssertionResponseJSON = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    clientDataJSON: typedefs.Base64URLString,
    authenticatorData: typedefs.Base64URLString,
    signature: typedefs.Base64URLString,
    userHandle: ?typedefs.Base64URLString = null,
};
