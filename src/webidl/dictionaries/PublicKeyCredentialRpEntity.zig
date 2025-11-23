//! WebIDL dictionary: PublicKeyCredentialRpEntity
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PublicKeyCredentialEntity = @import("PublicKeyCredentialEntity.zig").PublicKeyCredentialEntity;

pub const PublicKeyCredentialRpEntity = struct {
    // Inherited from PublicKeyCredentialEntity
    base: PublicKeyCredentialEntity,

    id: ?runtime.DOMString = null,
};
