//! WebIDL dictionary: AuthenticationExtensionsClientOutputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const CredentialPropertiesOutput = @import("CredentialPropertiesOutput.zig").CredentialPropertiesOutput;
const AuthenticationExtensionsPRFOutputs = @import("AuthenticationExtensionsPRFOutputs.zig").AuthenticationExtensionsPRFOutputs;
const AuthenticationExtensionsLargeBlobOutputs = @import("AuthenticationExtensionsLargeBlobOutputs.zig").AuthenticationExtensionsLargeBlobOutputs;
const HMACGetSecretOutput = @import("HMACGetSecretOutput.zig").HMACGetSecretOutput;
const AuthenticationExtensionsPaymentOutputs = @import("AuthenticationExtensionsPaymentOutputs.zig").AuthenticationExtensionsPaymentOutputs;

pub const AuthenticationExtensionsClientOutputs = struct {
    appid: ?bool = null,
    appidExclude: ?bool = null,
    credProps: ?CredentialPropertiesOutput = null,
    prf: ?AuthenticationExtensionsPRFOutputs = null,
    largeBlob: ?AuthenticationExtensionsLargeBlobOutputs = null,
    hmacCreateSecret: ?bool = null,
    hmacGetSecret: ?HMACGetSecretOutput = null,
    payment: ?AuthenticationExtensionsPaymentOutputs = null,
};
