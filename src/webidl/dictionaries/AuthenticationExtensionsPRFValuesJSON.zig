//! WebIDL dictionary: AuthenticationExtensionsPRFValuesJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AuthenticationExtensionsPRFValuesJSON = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    first: typedefs.Base64URLString,
    second: ?typedefs.Base64URLString = null,
};
