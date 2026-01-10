//! WebIDL dictionary: CookieInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const CookieInit = struct {
    name: runtime.USVString,
    value: runtime.USVString,
    expires: ?typedefs.DOMHighResTimeStamp = null,
    domain: ?runtime.USVString = null,
    path: ?runtime.USVString = null,
    sameSite: ?enums.CookieSameSite = null,
    partitioned: ?bool = null,
    maxAge: ?i64 = null,
};
