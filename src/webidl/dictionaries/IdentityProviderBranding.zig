//! WebIDL dictionary: IdentityProviderBranding
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const IdentityProviderIcon = @import("IdentityProviderIcon.zig").IdentityProviderIcon;

pub const IdentityProviderBranding = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    background_color: ?runtime.USVString = null,
    color: ?runtime.USVString = null,
    icons: ?[]const IdentityProviderIcon = null,
    name: ?runtime.USVString = null,
};
