//! WebIDL dictionary: AuthenticationExtensionsPRFInputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AuthenticationExtensionsPRFValues = @import("AuthenticationExtensionsPRFValues.zig").AuthenticationExtensionsPRFValues;

pub const AuthenticationExtensionsPRFInputs = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    eval: ?AuthenticationExtensionsPRFValues = null,
    evalByCredential: ?[]const struct {
        pub const webidl_record_entry = true;
        key: runtime.DOMString,
        value: AuthenticationExtensionsPRFValues,
    } = null,
};
