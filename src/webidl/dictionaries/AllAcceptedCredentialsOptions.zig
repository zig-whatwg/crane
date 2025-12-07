//! WebIDL dictionary: AllAcceptedCredentialsOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const AllAcceptedCredentialsOptions = struct {
    rpId: runtime.DOMString,
    userId: typedefs.Base64URLString,
    allAcceptedCredentialIds: []const typedefs.Base64URLString,
};
