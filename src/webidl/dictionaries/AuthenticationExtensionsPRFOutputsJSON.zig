//! WebIDL dictionary: AuthenticationExtensionsPRFOutputsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AuthenticationExtensionsPRFValuesJSON = @import("AuthenticationExtensionsPRFValuesJSON.zig").AuthenticationExtensionsPRFValuesJSON;

pub const AuthenticationExtensionsPRFOutputsJSON = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    enabled: ?bool = null,
    results: ?AuthenticationExtensionsPRFValuesJSON = null,
};
