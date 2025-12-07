//! WebIDL dictionary: PasswordCredentialData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const CredentialData = @import("CredentialData.zig").CredentialData;

pub const PasswordCredentialData = struct {
    // Inherited from CredentialData
    base: CredentialData,

    name: ?runtime.USVString = null,
    iconURL: ?runtime.USVString = null,
    origin: runtime.USVString,
    password: runtime.USVString,
};
