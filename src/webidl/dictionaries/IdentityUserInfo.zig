//! WebIDL dictionary: IdentityUserInfo
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const IdentityUserInfo = struct {
    email: ?runtime.USVString = null,
    name: ?runtime.USVString = null,
    givenName: ?runtime.USVString = null,
    picture: ?runtime.USVString = null,
};
