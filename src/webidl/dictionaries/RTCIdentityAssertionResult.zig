//! WebIDL dictionary: RTCIdentityAssertionResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCIdentityProviderDetails = @import("RTCIdentityProviderDetails.zig").RTCIdentityProviderDetails;

pub const RTCIdentityAssertionResult = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    idp: RTCIdentityProviderDetails,
    assertion: runtime.DOMString,
};
