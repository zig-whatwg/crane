//! WebIDL dictionary: IdentityProviderWellKnown
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const IdentityProviderWellKnown = struct {
    provider_urls: ?[]const runtime.USVString = null,
    accounts_endpoint: ?runtime.USVString = null,
    login_url: ?runtime.USVString = null,
};
