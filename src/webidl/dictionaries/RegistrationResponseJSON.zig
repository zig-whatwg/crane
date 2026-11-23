//! WebIDL dictionary: RegistrationResponseJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const AuthenticationExtensionsClientOutputsJSON = @import("AuthenticationExtensionsClientOutputsJSON.zig").AuthenticationExtensionsClientOutputsJSON;
const AuthenticatorAttestationResponseJSON = @import("AuthenticatorAttestationResponseJSON.zig").AuthenticatorAttestationResponseJSON;

pub const RegistrationResponseJSON = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    id: runtime.DOMString,
    rawId: typedefs.Base64URLString,
    response: AuthenticatorAttestationResponseJSON,
    authenticatorAttachment: ?runtime.DOMString = null,
    clientExtensionResults: AuthenticationExtensionsClientOutputsJSON,
    type: runtime.DOMString,
};
