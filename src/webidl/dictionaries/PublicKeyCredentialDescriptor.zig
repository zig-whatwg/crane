//! WebIDL dictionary: PublicKeyCredentialDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PublicKeyCredentialDescriptor = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    type: runtime.DOMString,
    id: typedefs.BufferSource,
    transports: ?[]const runtime.DOMString = null,
};
