//! WebIDL dictionary: IdentityProviderAccountList
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const IdentityProviderAccount = @import("IdentityProviderAccount.zig").IdentityProviderAccount;

pub const IdentityProviderAccountList = struct {
    accounts: ?[]const IdentityProviderAccount = null,
};
