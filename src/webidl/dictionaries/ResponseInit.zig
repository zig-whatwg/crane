//! WebIDL dictionary: ResponseInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ResponseInit = struct {
    status: ?u16 = null,
    statusText: ?runtime.DOMString = null,
    headers: ?anyopaque = null,
};
