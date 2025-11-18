//! WebIDL dictionary: AuthenticatorAssertionResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticatorAssertionResponseJSON = struct {
    clientDataJSON: anyopaque,
    authenticatorData: anyopaque,
    signature: anyopaque,
    userHandle: ?anyopaque = null,
};
