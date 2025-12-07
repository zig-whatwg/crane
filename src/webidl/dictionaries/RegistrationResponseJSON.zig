//! WebIDL dictionary: RegistrationResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const AuthenticationExtensionsClientOutputsJSON = @import("AuthenticationExtensionsClientOutputsJSON.zig").AuthenticationExtensionsClientOutputsJSON;
const AuthenticatorAttestationResponseJSON = @import("AuthenticatorAttestationResponseJSON.zig").AuthenticatorAttestationResponseJSON;

pub const RegistrationResponseJSON = struct {
    id: runtime.DOMString,
    rawId: typedefs.Base64URLString,
    response: AuthenticatorAttestationResponseJSON,
    authenticatorAttachment: ?runtime.DOMString = null,
    clientExtensionResults: AuthenticationExtensionsClientOutputsJSON,
    @"type": runtime.DOMString,
};
