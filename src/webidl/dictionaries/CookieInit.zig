//! WebIDL dictionary: CookieInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CookieInit = struct {
    name: runtime.DOMString,
    value: runtime.DOMString,
    expires: ?anyopaque = null,
    domain: ?anyopaque = null,
    path: ?runtime.DOMString = null,
    sameSite: ?anyopaque = null,
    partitioned: ?bool = null,
};
