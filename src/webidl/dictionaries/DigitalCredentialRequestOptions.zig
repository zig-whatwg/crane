//! WebIDL dictionary: DigitalCredentialRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const DigitalCredentialGetRequest = @import("DigitalCredentialGetRequest.zig").DigitalCredentialGetRequest;

pub const DigitalCredentialRequestOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    requests: []const DigitalCredentialGetRequest,
};
