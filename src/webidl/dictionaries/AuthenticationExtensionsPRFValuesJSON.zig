//! WebIDL dictionary: AuthenticationExtensionsPRFValuesJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const AuthenticationExtensionsPRFValuesJSON = struct {
    first: typedefs.Base64URLString,
    second: ?typedefs.Base64URLString = null,
};
