//! WebIDL dictionary: UnknownCredentialOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const UnknownCredentialOptions = struct {
    rpId: runtime.DOMString,
    credentialId: typedefs.Base64URLString,
};
