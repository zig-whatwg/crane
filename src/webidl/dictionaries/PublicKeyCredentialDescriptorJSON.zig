//! WebIDL dictionary: PublicKeyCredentialDescriptorJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PublicKeyCredentialDescriptorJSON = struct {
    type: runtime.DOMString,
    id: anyopaque,
    transports: ?anyopaque = null,
};
