//! WebIDL dictionary: AuthenticationExtensionsClientInputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const AuthenticationExtensionsPaymentInputs = @import("AuthenticationExtensionsPaymentInputs.zig").AuthenticationExtensionsPaymentInputs;
const AuthenticationExtensionsPRFInputs = @import("AuthenticationExtensionsPRFInputs.zig").AuthenticationExtensionsPRFInputs;
const AuthenticationExtensionsLargeBlobInputs = @import("AuthenticationExtensionsLargeBlobInputs.zig").AuthenticationExtensionsLargeBlobInputs;
const HMACGetSecretInput = @import("HMACGetSecretInput.zig").HMACGetSecretInput;

pub const AuthenticationExtensionsClientInputs = struct {
    appid: ?runtime.DOMString = null,
    appidExclude: ?runtime.DOMString = null,
    credProps: ?bool = null,
    prf: ?AuthenticationExtensionsPRFInputs = null,
    largeBlob: ?AuthenticationExtensionsLargeBlobInputs = null,
    credentialProtectionPolicy: ?runtime.USVString = null,
    enforceCredentialProtectionPolicy: ?bool = null,
    credBlob: ?*const anyopaque = null,
    getCredBlob: ?bool = null,
    minPinLength: ?bool = null,
    hmacCreateSecret: ?bool = null,
    hmacGetSecret: ?HMACGetSecretInput = null,
    payment: ?AuthenticationExtensionsPaymentInputs = null,
};
