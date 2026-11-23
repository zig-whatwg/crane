//! WebIDL dictionary: IdentityProviderAccountList
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const IdentityProviderAccount = @import("IdentityProviderAccount.zig").IdentityProviderAccount;

pub const IdentityProviderAccountList = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    accounts: ?[]const IdentityProviderAccount = null,
};
