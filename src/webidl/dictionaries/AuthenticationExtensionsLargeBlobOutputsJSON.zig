//! WebIDL dictionary: AuthenticationExtensionsLargeBlobOutputsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AuthenticationExtensionsLargeBlobOutputsJSON = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    supported: ?bool = null,
    blob: ?typedefs.Base64URLString = null,
    written: ?bool = null,
};
