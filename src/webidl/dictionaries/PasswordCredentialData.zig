//! WebIDL dictionary: PasswordCredentialData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const CredentialData = @import("CredentialData.zig").CredentialData;

pub const PasswordCredentialData = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from CredentialData
    base: CredentialData,

    name: ?runtime.USVString = null,
    iconURL: ?runtime.USVString = null,
    origin: runtime.USVString,
    password: runtime.USVString,
};
