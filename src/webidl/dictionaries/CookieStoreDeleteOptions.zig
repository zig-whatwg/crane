//! WebIDL dictionary: CookieStoreDeleteOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CookieStoreDeleteOptions = struct {
    name: runtime.DOMString,
    domain: ?anyopaque = null,
    path: ?runtime.DOMString = null,
    partitioned: ?bool = null,
};
