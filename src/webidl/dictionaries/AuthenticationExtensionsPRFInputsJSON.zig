//! WebIDL dictionary: AuthenticationExtensionsPRFInputsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AuthenticationExtensionsPRFValuesJSON = @import("AuthenticationExtensionsPRFValuesJSON.zig").AuthenticationExtensionsPRFValuesJSON;

pub const AuthenticationExtensionsPRFInputsJSON = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    eval: ?AuthenticationExtensionsPRFValuesJSON = null,
    evalByCredential: ?[]const struct {
        pub const webidl_record_entry = true;
        key: runtime.DOMString,
        value: AuthenticationExtensionsPRFValuesJSON,
    } = null,
};
