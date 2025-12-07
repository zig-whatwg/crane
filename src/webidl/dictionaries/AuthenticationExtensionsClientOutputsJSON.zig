//! WebIDL dictionary: AuthenticationExtensionsClientOutputsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const AuthenticationExtensionsPRFOutputsJSON = @import("AuthenticationExtensionsPRFOutputsJSON.zig").AuthenticationExtensionsPRFOutputsJSON;
const CredentialPropertiesOutput = @import("CredentialPropertiesOutput.zig").CredentialPropertiesOutput;
const AuthenticationExtensionsLargeBlobOutputsJSON = @import("AuthenticationExtensionsLargeBlobOutputsJSON.zig").AuthenticationExtensionsLargeBlobOutputsJSON;

pub const AuthenticationExtensionsClientOutputsJSON = struct {
    appid: ?bool = null,
    appidExclude: ?bool = null,
    credProps: ?CredentialPropertiesOutput = null,
    prf: ?AuthenticationExtensionsPRFOutputsJSON = null,
    largeBlob: ?AuthenticationExtensionsLargeBlobOutputsJSON = null,
};
