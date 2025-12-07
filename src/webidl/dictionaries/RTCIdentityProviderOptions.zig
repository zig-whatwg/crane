//! WebIDL dictionary: RTCIdentityProviderOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const RTCIdentityProviderOptions = struct {
    protocol: ?runtime.DOMString = null,
    usernameHint: ?runtime.DOMString = null,
    peerIdentity: ?runtime.DOMString = null,
};
