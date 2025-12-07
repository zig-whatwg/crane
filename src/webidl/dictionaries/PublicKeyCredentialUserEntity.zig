//! WebIDL dictionary: PublicKeyCredentialUserEntity
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const PublicKeyCredentialEntity = @import("PublicKeyCredentialEntity.zig").PublicKeyCredentialEntity;

pub const PublicKeyCredentialUserEntity = struct {
    // Inherited from PublicKeyCredentialEntity
    base: PublicKeyCredentialEntity,

    id: typedefs.BufferSource,
    displayName: runtime.DOMString,
};
