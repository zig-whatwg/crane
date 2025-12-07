//! WebIDL dictionary: AuthenticationResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const AuthenticationExtensionsClientOutputsJSON = @import("AuthenticationExtensionsClientOutputsJSON.zig").AuthenticationExtensionsClientOutputsJSON;
const AuthenticatorAssertionResponseJSON = @import("AuthenticatorAssertionResponseJSON.zig").AuthenticatorAssertionResponseJSON;

pub const AuthenticationResponseJSON = struct {
    id: runtime.DOMString,
    rawId: typedefs.Base64URLString,
    response: AuthenticatorAssertionResponseJSON,
    authenticatorAttachment: ?runtime.DOMString = null,
    clientExtensionResults: AuthenticationExtensionsClientOutputsJSON,
    @"type": runtime.DOMString,
};
