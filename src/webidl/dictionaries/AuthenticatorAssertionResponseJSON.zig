//! WebIDL dictionary: AuthenticatorAssertionResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticatorAssertionResponseJSON = struct {
    clientDataJSON: *const anyopaque,
    authenticatorData: *const anyopaque,
    signature: *const anyopaque,
    userHandle: ?*const anyopaque = null,
};
