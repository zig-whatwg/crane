//! WebIDL dictionary: FederatedCredentialInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const CredentialData = @import("CredentialData.zig").CredentialData;

pub const FederatedCredentialInit = struct {
    // Inherited from CredentialData
    base: CredentialData,

    name: ?runtime.DOMString = null,
    iconURL: ?runtime.DOMString = null,
    origin: runtime.DOMString,
    provider: runtime.DOMString,
    protocol: ?runtime.DOMString = null,
};
