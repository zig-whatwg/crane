//! WebIDL dictionary: FederatedCredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FederatedCredentialRequestOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    providers: ?[]const runtime.USVString = null,
    protocols: ?[]const runtime.DOMString = null,
};
