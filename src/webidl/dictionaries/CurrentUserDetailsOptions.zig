//! WebIDL dictionary: CurrentUserDetailsOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const CurrentUserDetailsOptions = struct {
    rpId: runtime.DOMString,
    userId: typedefs.Base64URLString,
    name: runtime.DOMString,
    displayName: runtime.DOMString,
};
