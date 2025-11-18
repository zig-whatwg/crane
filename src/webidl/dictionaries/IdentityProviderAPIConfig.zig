//! WebIDL dictionary: IdentityProviderAPIConfig
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IdentityProviderAPIConfig = struct {
    accounts_endpoint: runtime.DOMString,
    client_metadata_endpoint: ?runtime.DOMString = null,
    id_assertion_endpoint: runtime.DOMString,
    login_url: runtime.DOMString,
    disconnect_endpoint: ?runtime.DOMString = null,
    branding: ?anyopaque = null,
    supports_use_other_account: ?bool = null,
    account_label: ?runtime.DOMString = null,
};
