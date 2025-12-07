//! WebIDL dictionary: AuthenticationExtensionsPRFInputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const AuthenticationExtensionsPRFValues = @import("AuthenticationExtensionsPRFValues.zig").AuthenticationExtensionsPRFValues;

pub const AuthenticationExtensionsPRFInputs = struct {
    eval: ?AuthenticationExtensionsPRFValues = null,
    evalByCredential: ?[]const struct { key: runtime.DOMString, value: AuthenticationExtensionsPRFValues } = null,
};
