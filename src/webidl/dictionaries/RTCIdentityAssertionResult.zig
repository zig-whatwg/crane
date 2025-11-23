//! WebIDL dictionary: RTCIdentityAssertionResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RTCIdentityAssertionResult = struct {
    idp: *const anyopaque,
    assertion: runtime.DOMString,
};
