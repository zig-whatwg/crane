//! WebIDL dictionary: AuthenticationExtensionsClientInputsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AuthenticationExtensionsLargeBlobInputsJSON = @import("AuthenticationExtensionsLargeBlobInputsJSON.zig").AuthenticationExtensionsLargeBlobInputsJSON;
const AuthenticationExtensionsPRFInputsJSON = @import("AuthenticationExtensionsPRFInputsJSON.zig").AuthenticationExtensionsPRFInputsJSON;

pub const AuthenticationExtensionsClientInputsJSON = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    appid: ?runtime.DOMString = null,
    appidExclude: ?runtime.DOMString = null,
    credProps: ?bool = null,
    prf: ?AuthenticationExtensionsPRFInputsJSON = null,
    largeBlob: ?AuthenticationExtensionsLargeBlobInputsJSON = null,
    remoteClientDataJSON: ?runtime.DOMString = null,
};
