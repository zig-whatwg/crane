//! WebIDL dictionary: IdentityCredentialDisconnectOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const IdentityProviderConfig = @import("IdentityProviderConfig.zig").IdentityProviderConfig;

pub const IdentityCredentialDisconnectOptions = struct {
    // Inherited from IdentityProviderConfig
    base: IdentityProviderConfig,

    accountHint: runtime.USVString,
};
