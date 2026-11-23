//! WebIDL dictionary: AuthenticationExtensionsPRFOutputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AuthenticationExtensionsPRFValues = @import("AuthenticationExtensionsPRFValues.zig").AuthenticationExtensionsPRFValues;

pub const AuthenticationExtensionsPRFOutputs = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    enabled: ?bool = null,
    results: ?AuthenticationExtensionsPRFValues = null,
};
