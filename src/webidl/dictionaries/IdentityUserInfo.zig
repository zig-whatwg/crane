//! WebIDL dictionary: IdentityUserInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IdentityUserInfo = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    email: ?runtime.USVString = null,
    name: ?runtime.USVString = null,
    givenName: ?runtime.USVString = null,
    picture: ?runtime.USVString = null,
};
