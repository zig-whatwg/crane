//! WebIDL dictionary: URLPatternInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const URLPatternInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    protocol: ?runtime.USVString = null,
    username: ?runtime.USVString = null,
    password: ?runtime.USVString = null,
    hostname: ?runtime.USVString = null,
    port: ?runtime.USVString = null,
    pathname: ?runtime.USVString = null,
    search: ?runtime.USVString = null,
    hash: ?runtime.USVString = null,
    baseURL: ?runtime.USVString = null,
};
