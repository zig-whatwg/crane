//! WebIDL dictionary: RTCIdentityAssertionResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const RTCIdentityProviderDetails = @import("RTCIdentityProviderDetails.zig").RTCIdentityProviderDetails;

pub const RTCIdentityAssertionResult = struct {
    idp: RTCIdentityProviderDetails,
    assertion: runtime.DOMString,
};
