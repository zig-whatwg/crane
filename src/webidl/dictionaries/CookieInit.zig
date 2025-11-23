//! WebIDL dictionary: CookieInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CookieInit = struct {
    name: runtime.USVString,
    value: runtime.USVString,
    expires: ?*const anyopaque = null,
    domain: ?runtime.USVString = null,
    path: ?runtime.USVString = null,
    sameSite: ?*const anyopaque = null,
    partitioned: ?bool = null,
};
