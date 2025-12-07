//! WebIDL dictionary: IdentityProviderRequestOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const IdentityProviderConfig = @import("IdentityProviderConfig.zig").IdentityProviderConfig;

pub const IdentityProviderRequestOptions = struct {
    // Inherited from IdentityProviderConfig
    base: IdentityProviderConfig,

    loginHint: ?runtime.DOMString = null,
    domainHint: ?runtime.DOMString = null,
    fields: ?[]const runtime.USVString = null,
    params: ?v8.JSValue = null,
};
