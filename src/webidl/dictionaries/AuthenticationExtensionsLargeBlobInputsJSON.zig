//! WebIDL dictionary: AuthenticationExtensionsLargeBlobInputsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const AuthenticationExtensionsLargeBlobInputsJSON = struct {
    support: ?runtime.DOMString = null,
    read: ?bool = null,
    write: ?typedefs.Base64URLString = null,
};
