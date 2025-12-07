//! WebIDL dictionary: PublicKeyCredentialUserEntityJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PublicKeyCredentialUserEntityJSON = struct {
    id: typedefs.Base64URLString,
    name: runtime.DOMString,
    displayName: runtime.DOMString,
};
