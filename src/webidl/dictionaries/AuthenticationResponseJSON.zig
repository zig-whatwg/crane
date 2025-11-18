//! WebIDL dictionary: AuthenticationResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticationResponseJSON = struct {
    id: runtime.DOMString,
    rawId: anyopaque,
    response: anyopaque,
    authenticatorAttachment: ?runtime.DOMString = null,
    clientExtensionResults: anyopaque,
    type: runtime.DOMString,
};
