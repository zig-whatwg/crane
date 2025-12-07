//! WebIDL dictionary: AuthenticationExtensionsClientInputsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const AuthenticationExtensionsLargeBlobInputsJSON = @import("AuthenticationExtensionsLargeBlobInputsJSON.zig").AuthenticationExtensionsLargeBlobInputsJSON;
const AuthenticationExtensionsPRFInputsJSON = @import("AuthenticationExtensionsPRFInputsJSON.zig").AuthenticationExtensionsPRFInputsJSON;

pub const AuthenticationExtensionsClientInputsJSON = struct {
    appid: ?runtime.DOMString = null,
    appidExclude: ?runtime.DOMString = null,
    credProps: ?bool = null,
    prf: ?AuthenticationExtensionsPRFInputsJSON = null,
    largeBlob: ?AuthenticationExtensionsLargeBlobInputsJSON = null,
};
