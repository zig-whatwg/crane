//! WebIDL dictionary: IdentityProviderAccount
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const IdentityProviderAccount = struct {
    id: runtime.DOMString,
    name: ?runtime.DOMString = null,
    email: ?runtime.DOMString = null,
    tel: ?runtime.DOMString = null,
    username: ?runtime.DOMString = null,
    given_name: ?runtime.DOMString = null,
    picture: ?runtime.DOMString = null,
    approved_clients: ?anyopaque = null,
    login_hints: ?anyopaque = null,
    domain_hints: ?anyopaque = null,
    label_hints: ?anyopaque = null,
};
