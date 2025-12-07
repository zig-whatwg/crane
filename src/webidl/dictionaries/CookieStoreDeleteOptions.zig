//! WebIDL dictionary: CookieStoreDeleteOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CookieStoreDeleteOptions = struct {
    name: runtime.USVString,
    domain: ?runtime.USVString = null,
    path: ?runtime.USVString = null,
    partitioned: ?bool = null,
};
