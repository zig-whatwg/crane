//! WebIDL dictionary: AuthenticatorSelectionCriteria
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const AuthenticatorSelectionCriteria = struct {
    authenticatorAttachment: ?runtime.DOMString = null,
    residentKey: ?runtime.DOMString = null,
    requireResidentKey: ?bool = null,
    userVerification: ?runtime.DOMString = null,
};
