//! WebIDL dictionary: AuthenticationExtensionsClientOutputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const CredentialPropertiesOutput = @import("CredentialPropertiesOutput.zig").CredentialPropertiesOutput;
const AuthenticationExtensionsPRFOutputs = @import("AuthenticationExtensionsPRFOutputs.zig").AuthenticationExtensionsPRFOutputs;
const HMACGetSecretOutput = @import("HMACGetSecretOutput.zig").HMACGetSecretOutput;
const AuthenticationExtensionsPaymentOutputs = @import("AuthenticationExtensionsPaymentOutputs.zig").AuthenticationExtensionsPaymentOutputs;
const AuthenticationExtensionsLargeBlobOutputs = @import("AuthenticationExtensionsLargeBlobOutputs.zig").AuthenticationExtensionsLargeBlobOutputs;

pub const AuthenticationExtensionsClientOutputs = struct {
    hmacCreateSecret: ?bool = null,
    hmacGetSecret: ?HMACGetSecretOutput = null,
    payment: ?AuthenticationExtensionsPaymentOutputs = null,
    appid: ?bool = null,
    appidExclude: ?bool = null,
    credProps: ?CredentialPropertiesOutput = null,
    prf: ?AuthenticationExtensionsPRFOutputs = null,
    largeBlob: ?AuthenticationExtensionsLargeBlobOutputs = null,
};
