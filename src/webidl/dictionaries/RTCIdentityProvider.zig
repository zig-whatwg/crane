//! WebIDL dictionary: RTCIdentityProvider
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");

pub const RTCIdentityProvider = struct {
    generateAssertion: callbacks.GenerateAssertionCallback,
    validateAssertion: callbacks.ValidateAssertionCallback,
};
