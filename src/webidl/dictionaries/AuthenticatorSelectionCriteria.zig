//! WebIDL dictionary: AuthenticatorSelectionCriteria
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticatorSelectionCriteria = struct {
    authenticatorAttachment: ?runtime.DOMString = null,
    residentKey: ?runtime.DOMString = null,
    requireResidentKey: ?bool = null,
    userVerification: ?runtime.DOMString = null,
};
