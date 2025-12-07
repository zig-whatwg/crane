//! WebIDL dictionary: IdentityProviderAccount
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const IdentityProviderAccount = struct {
    id: runtime.USVString,
    name: ?runtime.USVString = null,
    email: ?runtime.USVString = null,
    tel: ?runtime.USVString = null,
    username: ?runtime.USVString = null,
    given_name: ?runtime.USVString = null,
    picture: ?runtime.USVString = null,
    approved_clients: ?[]const runtime.USVString = null,
    login_hints: ?[]const runtime.DOMString = null,
    domain_hints: ?[]const runtime.DOMString = null,
    label_hints: ?[]const runtime.DOMString = null,
};
