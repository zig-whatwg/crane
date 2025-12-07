//! WebIDL dictionary: AuthenticationExtensionsPRFInputsJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const AuthenticationExtensionsPRFValuesJSON = @import("AuthenticationExtensionsPRFValuesJSON.zig").AuthenticationExtensionsPRFValuesJSON;

pub const AuthenticationExtensionsPRFInputsJSON = struct {
    eval: ?AuthenticationExtensionsPRFValuesJSON = null,
    evalByCredential: ?[]const struct { key: runtime.DOMString, value: AuthenticationExtensionsPRFValuesJSON } = null,
};
