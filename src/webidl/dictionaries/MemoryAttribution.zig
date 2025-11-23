//! WebIDL dictionary: MemoryAttribution
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MemoryAttribution = struct {
    url: ?runtime.USVString = null,
    container: ?*const anyopaque = null,
    scope: ?runtime.DOMString = null,
};
