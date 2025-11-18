//! WebIDL dictionary: PublicKeyCredentialDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PublicKeyCredentialDescriptor = struct {
    type: runtime.DOMString,
    id: anyopaque,
    transports: ?anyopaque = null,
};
