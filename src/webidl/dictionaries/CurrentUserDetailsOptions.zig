//! WebIDL dictionary: CurrentUserDetailsOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CurrentUserDetailsOptions = struct {
    rpId: runtime.DOMString,
    userId: anyopaque,
    name: runtime.DOMString,
    displayName: runtime.DOMString,
};
