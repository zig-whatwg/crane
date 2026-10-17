//! WebIDL dictionary: FederatedCredentialInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const CredentialData = @import("CredentialData.zig").CredentialData;

pub const FederatedCredentialInit = struct {
    // Inherited from CredentialData
    base: CredentialData,

    name: ?runtime.USVString = null,
    iconURL: ?runtime.USVString = null,
    origin: runtime.USVString,
    provider: runtime.USVString,
    protocol: ?runtime.DOMString = null,
};
