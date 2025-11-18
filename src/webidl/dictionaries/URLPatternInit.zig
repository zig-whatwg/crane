//! WebIDL dictionary: URLPatternInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const URLPatternInit = struct {
    protocol: ?runtime.DOMString = null,
    username: ?runtime.DOMString = null,
    password: ?runtime.DOMString = null,
    hostname: ?runtime.DOMString = null,
    port: ?runtime.DOMString = null,
    pathname: ?runtime.DOMString = null,
    search: ?runtime.DOMString = null,
    hash: ?runtime.DOMString = null,
    baseURL: ?runtime.DOMString = null,
};
