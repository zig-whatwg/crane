//! WebIDL dictionary: AuthenticationExtensionsClientInputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AuthenticationExtensionsPaymentInputs = @import("AuthenticationExtensionsPaymentInputs.zig").AuthenticationExtensionsPaymentInputs;
const AuthenticationExtensionsPRFInputs = @import("AuthenticationExtensionsPRFInputs.zig").AuthenticationExtensionsPRFInputs;
const HMACGetSecretInput = @import("HMACGetSecretInput.zig").HMACGetSecretInput;
const AuthenticationExtensionsLargeBlobInputs = @import("AuthenticationExtensionsLargeBlobInputs.zig").AuthenticationExtensionsLargeBlobInputs;

pub const AuthenticationExtensionsClientInputs = struct {
    credentialProtectionPolicy: ?runtime.USVString = null,
    enforceCredentialProtectionPolicy: ?bool = null,
    credBlob: ?runtime.JSValue = null,
    getCredBlob: ?bool = null,
    minPinLength: ?bool = null,
    pinComplexityPolicy: ?bool = null,
    hmacCreateSecret: ?bool = null,
    hmacGetSecret: ?HMACGetSecretInput = null,
    payment: ?AuthenticationExtensionsPaymentInputs = null,
    appid: ?runtime.DOMString = null,
    appidExclude: ?runtime.DOMString = null,
    credProps: ?bool = null,
    prf: ?AuthenticationExtensionsPRFInputs = null,
    largeBlob: ?AuthenticationExtensionsLargeBlobInputs = null,
    remoteClientDataJSON: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "enforceCredentialProtectionPolicy", .{ .boolean = false } },
    };
};
