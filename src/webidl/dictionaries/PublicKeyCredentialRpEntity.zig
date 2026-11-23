//! WebIDL dictionary: PublicKeyCredentialRpEntity
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PublicKeyCredentialEntity = @import("PublicKeyCredentialEntity.zig").PublicKeyCredentialEntity;

pub const PublicKeyCredentialRpEntity = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from PublicKeyCredentialEntity
    base: PublicKeyCredentialEntity,

    id: ?runtime.DOMString = null,
};
