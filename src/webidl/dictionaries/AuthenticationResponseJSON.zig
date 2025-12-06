//! WebIDL dictionary: AuthenticationResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticationResponseJSON = struct {
    id: runtime.DOMString,
    rawId: *const anyopaque,
    response: *const anyopaque,
    authenticatorAttachment: ?runtime.DOMString = null,
    clientExtensionResults: *const anyopaque,
    type: runtime.DOMString,
};
