//! WebIDL dictionary: AllAcceptedCredentialsOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AllAcceptedCredentialsOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    rpId: runtime.DOMString,
    userId: typedefs.Base64URLString,
    allAcceptedCredentialIds: []const typedefs.Base64URLString,
};
