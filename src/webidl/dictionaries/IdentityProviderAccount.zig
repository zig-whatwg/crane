//! WebIDL dictionary: IdentityProviderAccount
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IdentityProviderAccount = struct {
    id: runtime.USVString,
    name: ?runtime.USVString = null,
    email: ?runtime.USVString = null,
    tel: ?runtime.USVString = null,
    username: ?runtime.USVString = null,
    given_name: ?runtime.USVString = null,
    picture: ?runtime.USVString = null,
    approved_clients: ?*const anyopaque = null,
    login_hints: ?*const anyopaque = null,
    domain_hints: ?*const anyopaque = null,
    label_hints: ?*const anyopaque = null,
};
