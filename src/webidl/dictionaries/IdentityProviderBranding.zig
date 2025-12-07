//! WebIDL dictionary: IdentityProviderBranding
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const IdentityProviderIcon = @import("IdentityProviderIcon.zig").IdentityProviderIcon;

pub const IdentityProviderBranding = struct {
    background_color: ?runtime.USVString = null,
    color: ?runtime.USVString = null,
    icons: ?[]const IdentityProviderIcon = null,
    name: ?runtime.USVString = null,
};
