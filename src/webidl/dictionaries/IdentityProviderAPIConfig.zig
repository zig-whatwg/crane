//! WebIDL dictionary: IdentityProviderAPIConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const IdentityProviderBranding = @import("IdentityProviderBranding.zig").IdentityProviderBranding;

pub const IdentityProviderAPIConfig = struct {
    accounts_endpoint: runtime.USVString,
    client_metadata_endpoint: ?runtime.USVString = null,
    id_assertion_endpoint: runtime.USVString,
    login_url: runtime.USVString,
    disconnect_endpoint: ?runtime.USVString = null,
    branding: ?IdentityProviderBranding = null,
    supports_use_other_account: ?bool = null,
    account_label: ?runtime.USVString = null,
};
